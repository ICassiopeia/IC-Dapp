mod types;

use crate::types::*;
use itertools::Itertools;
use std::collections::HashMap;
use std::cell::RefCell;
use ic_cdk::api::{time};
use ic_cdk::api::call::CallResult;
use ic_cdk::storage;
use ic_cdk_macros::{self, init, post_upgrade, pre_upgrade, query, update};
use ic_cdk::export::Principal;

thread_local! {
    static STATE: RefCell<State> = RefCell::default();
}

#[init]
fn init() {
    STATE.with(|state| {
        *state.borrow_mut() = State {
            stable: StableState {
                datasets: HashMap::new(),
                dataset_values: HashMap::new(),
                dataset_owners: HashMap::new(),
                dataset_producers: HashMap::new(),
                queries: HashMap::new(),
                analytics_tokens: HashMap::new(),
                next_dataset_id: 0,
                next_query_id: 0,
            },
        };
    });
}

#[pre_upgrade]
fn pre_upgrade() {
    STATE.with(|state| storage::stable_save((&state.borrow().stable,)).unwrap());
}

#[post_upgrade]
fn post_upgrade() {
    let (stable,): (StableState,) = storage::stable_restore().unwrap();
    STATE.with(|state| *state.borrow_mut() = State { stable });
}

#[update(name = "createDataSet")]
async fn create_data_set(request: DatasetCreateRequest) -> u32 {
    STATE.with(|map| {
        let mut map = map.borrow_mut();
        let mut id = map.stable.next_dataset_id;
        id += 1;
        // Register dataset config
        let now = time();
        let dataset_config = DatasetConfiguration {
            name: request.dataset_config.name,
            description: request.dataset_config.description,
            jupyter_notebook: request.dataset_config.jupyter_notebook,
            asset_id: request.dataset_config.asset_id,
            dimensions: request.dataset_config.dimensions,
            is_active: true,
            category: request.category,
            created_at: now,
            updated_at: now,
        };
        map.stable.datasets.insert(id, dataset_config);
        let caller: Principal = ic_cdk::api::caller();
        // Update dataset ownership
        if let Some(array) = map.stable.dataset_owners.get_mut(&caller) {
            array.push(id);
        } else {
            map.stable.dataset_owners.insert(caller, vec![id]);
        };
        // Configure init producer
        let new_producer = ProducerState {id:caller, is_enabled:true, created_at: time()};
        map.stable.dataset_producers.insert(id, vec![new_producer]);
        id
    })
}


#[update(name = "deleteDataSet")]
async fn delete_data_set(dataset_id: u32) -> () {
    STATE.with(|map| {
        let mut map = map.borrow_mut();
        map.stable.datasets.remove(&dataset_id);
        map.stable.dataset_producers.remove(&dataset_id);
    });
}

#[query(name = "getProducers")]
fn get_producers(dataset_id: u32) -> Option<Vec<ProducerState>> {
    STATE.with(|map| {
        map.borrow().stable.dataset_producers.get(&dataset_id).cloned()
    })
}

#[query(name = "getDatasetsWhereUserIsProducers")]
fn get_datasets_where_user_is_producers() -> Vec<u32> {
    STATE.with(|map| {
        let user = ic_cdk::api::caller();
        map.borrow().stable.dataset_producers
            .iter()
            .filter(|x| x.1.iter().find(|y| y.id==user).is_some())
            .map(|x| x.0)
            .cloned()
            .collect()
    })
}

#[query(name = "isUserProducer")]
fn is_user_producer(dataset_id: u32) -> bool {
    STATE.with(|map| {
        match map.borrow().stable.dataset_producers.get(&dataset_id) {
            Some(producers) => {
                let caller = ic_cdk::api::caller();
                producers.iter()
                    .find(|prod|prod.id == caller)
                    .is_some()
                },
            None => false
        }
    })
}

#[query(name = "myUser")]
fn my_user() -> Principal {
    ic_cdk::api::caller()
}

#[update(name = "updateProducerList")]
async fn update_producer_list(dataset_id : u32, user: Principal, mode: UpdateMode) -> () {
    // assert user is owner
    let caller = ic_cdk::api::caller();
    let test = STATE.with(|map| {
        match map.borrow().stable.dataset_owners.get(&caller) {
            Some(owners) => owners.contains(&dataset_id),
            None => false,
        }
    });
    assert!(test);

    let new_entry = vec![ ProducerState {id: user, is_enabled:true, created_at: time()}];
    STATE.with(|map| {
        let mut map = map.borrow_mut();
        match map.stable.dataset_producers.get_mut(&dataset_id) {
            Some(producers) => {
                if mode == UpdateMode::Add {
                    producers.extend(new_entry);
                }
                else {
                    producers.retain(|x| x.id != user);
                }
            },
            None => {
                if mode == UpdateMode::Add {
                    map.stable.dataset_producers.insert(dataset_id, new_entry);
                }
            }
        }
    })
}

#[query(name = "searchDataset")]
fn search_dataset(search : String) -> Vec<u32> {
    STATE.with(|map| {
       map.borrow().stable.datasets
        .iter()
        .filter_map(|(&k, ref v)| if v.name.contains(&search) || v.description.contains(&search) {Some(k)} else {None})
        .collect()
    })
}

#[query(name = "getDatasetOwnerships")]
fn get_dataset_ownerships() -> Vec<(Principal, Vec<u32>)> {
    STATE.with(|map| {
       map.borrow().stable.dataset_owners
       .iter()
       .map(|(&x, y)| (x, y.clone()))
       .collect()
    })
}

#[query(name = "getDatasetByDatasetId")]
fn get_dataset_by_dataset_id(dataset_id : u32) -> Option<DatasetConfiguration> {
    STATE.with(|map| {
        map.borrow().stable.datasets.get(&dataset_id).cloned()
    })
}

#[query(name = "getAllDatasets")]
fn get_all_datasets() -> Vec<(u32, DatasetConfiguration)> {
    STATE.with(|map| {
       map.borrow().stable.datasets
        .iter()
        .map(|(k,v)| (k.clone(), v.clone()))
        .collect()
    })
}

#[query(name = "getManyDatasets")]
fn get_many_datasets(ids : Vec<u32>) -> Vec<(u32, Option<DatasetConfiguration>)> {
    STATE.with(|map| {
        let map = map.borrow();
        ids.iter()
            .map(|id| (*id, map.stable.datasets.get(&id).cloned()))
            .collect()
    })
}

#[query(name = "getUserDatasets")]
fn get_user_datasets(user_id : Principal) -> Option<Vec<u32>> {
    STATE.with(|map| {
        map.borrow().stable.dataset_owners.get(&user_id).cloned()
    })
}

#[query(name = "getUserDataByDatasetId")]
fn get_user_data_by_dataset_id(dataset_id : u32) -> Vec<DatasetEntry> {
    STATE.with(|map| {
        match map.borrow().stable.dataset_values.get(&dataset_id) {
            Some(values) => values.iter().filter(|&record| record.id == RecordKey::User(ic_cdk::api::caller())).cloned().collect::<Vec<DatasetEntry>>(),
            None => vec![]
        }
    })
}

#[query(name = "getDatasetEntryCounts")]
fn get_dataset_entry_counts(dataset_ids : Vec<u32>) -> Vec<(u32, usize)> {
    dataset_ids
        .iter()
        .map(|id| {
            let nb_values: usize = STATE.with(|map| map.borrow().stable.dataset_values.get(&id).unwrap().iter().len());
            (*id, nb_values)
        })
        .collect()
}

fn put_entry(caller: Principal, dataset_id: u32, dataset_value: &DatasetEntryInput, mode: UpdateMode) -> () {
    let now = time();
    let entry = DatasetEntry {
        id: dataset_value.id,
        producer: caller,
        values: dataset_value.values.iter().cloned().collect(),
        created_at: now,
        updated_at: now,
    };
    STATE.with(|map| {
        let mut map = map.borrow_mut();
        match map.stable.dataset_values.get_mut(&dataset_id) {
            Some(values) => {
                let mut entries = vec![entry];
                if mode == UpdateMode::Add { entries.extend(values.clone()); }
                map.stable.dataset_values.insert(dataset_id, entries);
            },
            None => {
                if mode == UpdateMode::Add { map.stable.dataset_values.insert(dataset_id, vec![entry]); }
                else {}
            }
        }
    })
}

#[update(name = "putManyEntries")]
fn put_many_entries(dataset_id: u32, dataset_values: Vec<DatasetEntryInput>) -> () {
    let caller = ic_cdk::api::caller();
    for value in dataset_values.iter() {
        put_entry(caller, dataset_id, value, UpdateMode::Add)
    };
}

#[update(name = "deleteUserEntry")]
fn delete_user_entry(dataset_id: u32) -> () {
    delete_data_entry(ic_cdk::api::caller(), dataset_id)
}

fn delete_data_entry(caller: Principal, dataset_id: u32) -> () {
    STATE.with(|map| {
        let mut map = map.borrow_mut();
        match map.stable.dataset_values.get_mut(&dataset_id) {
            Some(values) => {
                let filtered_values: Vec<DatasetEntry>= values.iter().filter(|&x| x.id == RecordKey::User(caller)).cloned().collect();
                if filtered_values.len() > values.len() { map.stable.dataset_values.insert(dataset_id, filtered_values); }
                else {()}
            },
            None => ()
        }
    })
}

// GDPR - Data Protection
#[update(name = "deleteAllEntriesOfUser")]
fn delete_all_entries_of_user() -> () {
    STATE.with(|map| {
        let caller = ic_cdk::api::caller();
        for id in map.borrow().stable.datasets.keys() {
            delete_data_entry(caller, *id)
        }
    })
}

// Analytical functions
fn get_data_by_dataset_id(dataset_id : u32, sample: Option<u32>, attributes: Option<Vec<u8>>) -> Vec<DatasetEntry> {
    STATE.with(|map| {
        let mut values = map.borrow().stable.dataset_values.get(&dataset_id).cloned().unwrap_or(vec![]);
        values = match attributes {
            Some(att) => values
                .iter()
                .map(|x| {
                    let filtered_values = x.values.iter().filter(|y| att.contains(&y.dimension_id)).cloned().collect();
                    DatasetEntry {
                        values: filtered_values,
                        ..x.clone()
                    }
                })
                .collect(),
            None => values
        };
        match sample {
            Some(limit) => values.into_iter().by_ref().take(limit as usize).collect(),
            None => values
        }
    })
}

#[query(name = "getProducersStats")]
fn get_producers_stats(dataset_id : u32) -> Vec<(Principal, u32)> {
    STATE.with(|map| {
        match map.borrow().stable.dataset_values.get(&dataset_id) {
            Some(values) => {
                values
                    .clone()
                    .iter()
                    .group_by(|x| x.producer)
                    .into_iter()
                    .map(|(id, records)| {
                        let count = records.into_iter().count();
                        (id, count as u32)
                    })
                    .collect()
                },
            None => vec![]
        }
    })
}

#[query(name = "getDatasetActivity")]
fn get_dataset_activity(
    dataset_id : u32,
) -> Option<Vec<DateMetrics>> {
    STATE.with(|map| {
        match map.borrow().stable.dataset_values.get(&dataset_id) {
            Some(entries) => {
                let res = entries
                    .iter()
                    .group_by(|rec| (rec.created_at / 86_400_000_000) * 86_400_000_000)
                    .into_iter()
                    .map(|(k, v)| DateMetrics {date: k, value: v.count() as u32})
                    .collect::<Vec<DateMetrics>>();
                Some(res)
            },
            None => {None}
        }
    })
}

#[query(name = "getDatasetQueryActivity")]
fn get_dataset_query_activity(
    dataset_id : u32,
) -> Vec<DateMetrics> {
    STATE.with(|map| {
        map.borrow().stable.queries
            .iter()
            .filter(|(_, query)| query.query_meta.dataset_id == dataset_id)
            .group_by(|(_, query)| (query.timestamp / 86_400_000_000) * 86_400_000_000 )
            .into_iter()
            .map(|(k, v)| DateMetrics {date: k, value: v.count() as u32})
            .collect::<Vec<DateMetrics>>()
    })
}

async fn get_dataset_athorized_columns(dataset_id : u32, caller: Principal) -> (Vec<u8>, bool) {
    let canister_id: &str = option_env!("CANISTER_ID_fractional_NFT").expect("Could not decode the principal of NFT canister.");
    let access_request: CallResult<(Vec<NftMetadata>,)> = ic_cdk::call(
            Principal::from_text(canister_id).expect("Could not decode the principal."),
            "getUserDatasetAccess",
            (dataset_id, caller)
        ).await;
    
    match access_request {
        Err((_, _)) => (vec![], false),
        Ok((result,)) => {
            if result.len()>=1 {
                (result
                    .iter()
                    .map(|x| x.dimensionRestrictList.clone())
                    .flatten()
                    .unique()
                    .collect::<Vec<u8>>()
                , result[0].isGdrpEnabled)
            } else {
                (vec![], false)
            }
        },
    }
}

#[update(name = "getAnalytics")]
async fn get_analytics(query: QueryInput, token_data : Option<String>) -> Result<AnalyticsSuperType, String> {
    // Check NFT ownership
    let ic_caller = ic_cdk::api::caller();
    let caller = process_token_data(ic_caller, token_data);
    match caller {
        Ok(_caller) => {
            let (authorized, is_gdpr_enabled) = get_dataset_athorized_columns(query.dataset_id, _caller.clone()).await;
            if authorized.len()>=1 {
                let mut requested_fields = query.attributes.clone();
                requested_fields.extend(query.metrics.clone());
                let unauthorized_attributes = requested_fields
                    .iter()
                    .filter(|x| !authorized.contains(x))
                    .cloned()
                    .collect::<Vec<u8>>();
        
                if unauthorized_attributes.len()==0 {
                    STATE.with(|map| {
                        let mut id = map.borrow_mut().stable.next_query_id;
                        id += 1;
                        let query_state = QueryState::Pending;
                        let now = time();
                        let final_query = Query {
                            timestamp: now,
                            user: _caller,
                            query_meta: query.clone(),
                            query_state: query_state.clone(),
                            is_gdpr: is_gdpr_enabled.clone(),
                            gdpr_limit: 5,
                        };
                        map.borrow_mut().stable.queries.entry(id.clone()).or_insert(final_query);
                        Ok(fetch_analytics(
                            query.dataset_id,
                            query.attributes,
                            query.metrics,
                            query.filters,
                            is_gdpr_enabled,
                            5,
                        ))
                    })
                } else {
                    return Err("User does not have access to following attributes".to_string());
                }
            } else  {
                Err("User does not own NFT linked to this dataset.".to_string())
            }
        },
        Err(_msg) => Err(_msg.to_string()),
    }
}

#[update(name = "getAuthorizedColumns")]
async fn get_authorized_columns(dataset_id : u32) -> (Vec<u8>, bool)  {
    let caller = ic_cdk::api::caller();
    get_dataset_athorized_columns(dataset_id, caller).await
}

fn fetch_analytics(
    dataset_id : u32,
    attributes : Vec<u8>,
    metrics : Vec<u8>,
    filters : Vec<(u8, Value)>,
    is_gdpr : bool,
    gdpr_limit : u32
) -> AnalyticsSuperType {
    STATE.with(|map| {
        match map.borrow().stable.dataset_values.get(&dataset_id) {
            Some(values) => {
                // 1. Filter & prepare data
                let mut base_data =  values.clone();
                let op0_size: u32 = base_data.clone().len() as u32;
                if filters.len() > 0 {
                    base_data
                        .retain(|rec| {
                            !filters.iter().any(|y| rec.values.iter().any(|val| y.0==val.dimension_id && y.1==val.value))
                        })
                };
                let op1_size: u32 = base_data.clone().len() as u32;

                // 2. Prepare data
                fn transform_record(att: &Vec<u8>, met: &Vec<u8>, record: &DatasetEntry) -> AnayticsPrep {
                    let attribute_values = record.values
                        .iter()
                        .filter_map(|val| if att.contains(&val.dimension_id) {Some(val.value.clone())} else {None} )
                        .collect::<Vec<Value>>();

                    let mut metrics_values = record.values.clone();
                    metrics_values.retain(|val| met.contains(&val.dimension_id));
                    AnayticsPrep {
                        att_hash: attribute_values.iter().join("--"),
                        att: attribute_values,
                        met: metrics_values
                    }
                }
                let mut prepared_data: Vec<AnayticsPrep> = base_data
                    .iter()
                    .map(|rec| transform_record(&attributes, &metrics, rec))
                    .collect();
                prepared_data.sort_by(|x, y| x.att_hash.cmp(&y.att_hash));
                let op2_size: u32 = prepared_data.clone().len() as u32;

                // 3. Aggregate
                let mut aggregated = prepared_data
                    .iter()
                    .group_by(|&x| x.att_hash.clone())
                    .into_iter()
                    .map(|(ids, records)| -> AnalyticsType {
                        let aggregates: (HashMap::<u8, u32>, Vec<Value>, usize) = records
                            .into_iter()
                            .fold((HashMap::<u8, u32>::new(), vec![], 0), |(mut acc, mut attributes, mut count), record| {
                                if attributes.len()==0 {attributes = record.att.clone();}
                                count += 1;
                                for metric in metrics.iter() {
                                    match record.met.iter().find(|val| val.dimension_id == *metric) {
                                        Some(value) => {
                                            let sum = acc.entry(value.dimension_id).or_insert(0);
                                            match value.value {
                                                Value::Metric(x) => *sum += x,
                                                _ => {}
                                            }
                                        },
                                        None => {}
                                    }
                                };
                                (acc, attributes, count)
                            });
                        let res = AnalyticsType {
                            group_key: ids,
                            attributes: aggregates.1.clone(),
                            metrics: aggregates.0.clone(),
                            count: aggregates.2.clone() as u32,
                        };
                        res
                    })
                    .collect::<Vec<AnalyticsType>>();
                let op3_size: u32 = aggregated.clone().len() as u32;

                // 4. GDPR
                if is_gdpr && gdpr_limit>0 {
                    aggregated
                        .retain(|x| &x.count > &gdpr_limit);
                }
                let op4_size: u32 = aggregated.clone().len() as u32;

                AnalyticsSuperType {
                    analytics: aggregated,
                    counts: (op0_size, op1_size, op2_size, op3_size, op4_size),
                }
            },
            None => AnalyticsSuperType {
                analytics: vec![],
                counts: (0u32, 0u32, 0u32, 0u32, 0u32),
            }
        }
    })
}


fn process_token_data(
    ic_caller : Principal,
    token : Option<String>,
) -> Result<Principal, String> {
    match token {
        Some(_token_data) => {
            STATE.with(|map| {
                let map = map.borrow();
                let token_search = map.stable.analytics_tokens
                    .iter()
                    .find(|(_, ref y)| y.token==_token_data)
                    .clone();

                match token_search {
                    Some(token_record) => {
                        // Check token validity
                        // if entry.token==token {
                        Ok(token_record.0.clone())
                        // } else {
                        //     Err("Invalid token".to_string())
                        // }
                    },
                    None => Err("Token not found in backend".to_string()),
                }
            })
        },
        None => {
            if ic_caller.to_text() == "2vxsx-fae" {
                Err("Anonymous identity without token is unauthorized".to_string())
            } else {
                Ok(ic_caller)
            }
        },
    }
}

#[update(name = "getDatasetDownload")]
async fn get_dataset_download(dataset_id : u32, token_data: Option<String>) -> Result<Vec<DatasetEntry>, String> {
    let ic_caller = ic_cdk::api::caller();
    let caller = process_token_data(ic_caller, token_data);
    match caller {
        Ok(_caller) => {
            let (authorized, _) = get_dataset_athorized_columns(dataset_id, _caller).await;
            Ok(get_data_by_dataset_id(dataset_id, None, Some(authorized)))
        },
        Err(_msg) => Err(_msg.to_string()),
    }
}

#[query(name = "getDatasetSample")]
fn get_dataset_sample(dataset_id : u32) -> Vec<DatasetEntry> {
    get_data_by_dataset_id(dataset_id, Some(30), None)
}

#[update(name = "registerAnalyticsToken")]
fn register_analytics_token(token: String) -> String {
    STATE.with(|map| {
        let now = time();
        let token_state = AnalyticsToken {
            token: token.clone(),
            lifetime: 3600,
            created_at: now,
            expire_at: now,
        };
        map.borrow_mut().stable.analytics_tokens.insert(ic_cdk::api::caller(), token_state);
        token
    })
}