use itertools::Itertools;
use data_assets::*;
use std::collections::HashMap;
use std::cell::RefCell;
use std::env;
use std::mem;
use ic_cdk::api::time;

use ic_cdk::storage;
use ic_cdk_macros::{self, post_upgrade, pre_upgrade, query, update};
use ic_cdk::export::Principal;


thread_local! {
    pub static DATASETS: RefCell<HashMap<u32, DatasetConfiguration>>  = RefCell::new(HashMap::new());
    pub static DATASET_VALUES: RefCell<HashMap<u32, Vec<DatasetEntry>>> = RefCell::new(HashMap::new());
    pub static DATASET_OWNERS: RefCell<HashMap<Principal, Vec<u32>>> = RefCell::new(HashMap::new());
    pub static DATASET_PRODUCERS: RefCell<HashMap<u32, Vec<ProducerState>>> = RefCell::new(HashMap::new());
    pub static QUERIES: RefCell<HashMap<u32, Query>> = RefCell::new(HashMap::new());
    pub static NEXT_DATASET_ID: RefCell<u32> = RefCell::new(0);
    pub static NEXT_QUERY_ID: RefCell<u32> = RefCell::new(0);
}
// #[ic_cdk_macros::import(canister = "fractional_NFT")]
// struct ImportedCanister;


#[update(name = "createDataSet")]
async fn create_data_set(request: DatasetCreateRequest) -> u32 {
    NEXT_DATASET_ID.with(|current_id| {
        let mut id = current_id.borrow_mut();
        *id += 1;
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
        DATASETS.with(|map| {
            let mut map = map.borrow_mut();
            map.insert(*id, dataset_config)
        });
        let caller: Principal = ic_cdk::api::caller();
        DATASET_OWNERS.with(|map| {
            let mut map: std::cell::RefMut<HashMap<Principal, Vec<u32>>> = map.borrow_mut();
            if let Some(array) = map.get_mut(&caller) {
                array.push(*id);
            } else {
                // Otherwise, insert a new key-value pair into the hashmap
                map.insert(caller, vec![*id]);
            }
        });
        // Configure init producer
        DATASET_PRODUCERS.with(|map| {
            let mut map = map.borrow_mut(); 
            let new_producer = ProducerState {id:caller, is_enabled:true};
            map.insert(*id, vec![new_producer]);
        });
        *id
    })
}


#[update(name = "deleteDataSet")]
async fn delete_data_set(dataset_id: u32) -> () {
    DATASETS.with(|map| {
        map.borrow_mut().remove(&dataset_id)
    });
    DATASET_PRODUCERS.with(|map| {
        map.borrow_mut().remove(&dataset_id)
    });
}

#[query(name = "getProducers")]
fn get_producers(dataset_id: u32) -> Option<Vec<ProducerState>> {
    DATASET_PRODUCERS.with(|map| {
        map.borrow().get(&dataset_id).cloned()
    })
}

#[query(name = "isUserProducer")]
fn is_user_producer(dataset_id: u32) -> bool {
    DATASET_PRODUCERS.with(|map| {
        match map.borrow().get(&dataset_id) {
            Some(producers) => {producers.clone().iter().filter(|prod|prod.id == ic_cdk::api::caller()).collect::<Vec<&ProducerState>>().len() > 0},
            None => false
        }
    })
}

#[update(name = "updateProducerList")]
async fn update_producer_list(dataset_id : u32, user: Principal, mode: UpdateMode) -> () {
    let new_entry = vec![ ProducerState {id: user, is_enabled:true}];
    DATASET_PRODUCERS.with(|map| {
        let mut map: std::cell::RefMut<HashMap<u32, Vec<ProducerState>>> = map.borrow_mut();
        match map.get_mut(&dataset_id) {
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
                    map.insert(dataset_id, new_entry);
                }
            }
        }
    })
}

#[query(name = "searchDataset")]
fn search_dataset(search : String) -> Vec<u32> {
    DATASETS.with(|map| {
       map.borrow()
        .iter()
        .filter_map(|(&k, ref v)| if v.name.contains(&search) || v.description.contains(&search) {Some(k)} else {None})
        .collect()
    })
}

#[query(name = "getDatasetByDatasetId")]
fn get_dataset_by_dataset_id(dataset_id : u32) -> Option<DatasetConfiguration> {
    DATASETS.with(|map| {
        map.borrow().get(&dataset_id).cloned()
    })
}

#[query(name = "getAllDatasets")]
fn get_all_datasets() -> Vec<(u32, DatasetConfiguration)> {
    DATASETS.with(|map: &RefCell<HashMap<u32, DatasetConfiguration>>| {
       map.borrow()
        .iter()
        .map(|(k,v)| (k.clone(), v.clone()))
        .collect()
    })
}

#[query(name = "getManyDatasets")]
fn get_many_datasets(ids : Vec<u32>) -> Vec<(u32, Option<DatasetConfiguration>)> {
    DATASETS.with(|map| {
        let map = map.borrow();
        ids.iter()
            .map(|id| (*id, map.get(&id).cloned()))
            .collect()
    })
}

#[query(name = "getUserDatasets")]
fn get_user_datasets(user_id : Principal) -> Option<Vec<u32>> {
    DATASET_OWNERS.with(|map| {
        map.borrow().get(&user_id).cloned()
    })
}

#[query(name = "getUserDataByDatasetId")]
fn get_user_data_by_dataset_id(dataset_id : u32) -> Vec<DatasetEntry> {
    DATASET_VALUES.with(|map: &RefCell<HashMap<u32, Vec<DatasetEntry>>>| {
        match map.borrow().get(&dataset_id) {
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
            let nb_values: usize = DATASET_VALUES.with(|map| map.borrow().get(&id).unwrap().iter().len());
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
    DATASET_VALUES.with(|map| {
        let mut map = map.borrow_mut();
        match map.get_mut(&dataset_id) {
            Some(values) => {
                let mut entries = vec![entry];
                if mode == UpdateMode::Add { entries.extend(values.clone()); }
                map.insert(dataset_id, entries);
            },
            None => {
                if mode == UpdateMode::Add { map.insert(dataset_id, vec![entry]); }
                else {}
            }
        }
    })
}

#[update(name = "putManyEntries")]
fn put_many_entries(dataset_id: u32, dataset_values: Vec<DatasetEntryInput>) -> () {
    for value in dataset_values.iter() {
        put_entry(ic_cdk::api::caller(), dataset_id, value, UpdateMode::Add)
    };
}

#[update(name = "deleteUserEntry")]
fn delete_user_entry(dataset_id: u32) -> () {
    delete_data_entry(ic_cdk::api::caller(), dataset_id)
}

fn delete_data_entry(caller: Principal, dataset_id: u32) -> () {
    DATASET_VALUES.with(|map| {
        let mut map = map.borrow_mut();
        match map.get_mut(&dataset_id) {
            Some(values) => {
                let filtered_values: Vec<DatasetEntry>= values.iter().filter(|&x| x.id == RecordKey::User(caller)).cloned().collect();
                if filtered_values.len() > values.len() { map.insert(dataset_id, filtered_values); }
                else {()}
            },
            None => ()
        }
    })
}

// GDPR - Data Protection
#[update(name = "deleteAllEntriesOfUser")]
fn delete_all_entries_of_user() -> () {
    DATASETS.with(|map| {
        for id in map.borrow().keys() {
            delete_data_entry(ic_cdk::api::caller(), *id)
        }
    })
}

// Analytical functions
fn get_data_by_dataset_id(dataset_id : u32, sample: Option<u32>, attributes: Option<Vec<u8>>) -> Vec<DatasetEntry> {
    DATASET_VALUES.with(|map| {
        let mut values = map.borrow().get(&dataset_id).cloned().unwrap_or(vec![]);
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
fn get_producers_stats(dataset_id : u32) -> Vec<(Principal, usize)> {
    DATASET_VALUES.with(|map| {
        match map.borrow().get(&dataset_id) {
            Some(values) => {
                values
                    .clone()
                    .iter()
                    .group_by(|x| x.producer)
                    .into_iter()
                    .map(|(id, records)| {
                        let count = records.into_iter().count();
                        (id, count)
                    })
                    .collect()
                },
            None => vec![(ic_cdk::api::caller(), 0)]
        }
    })
}

#[query(name = "getDatasetActivity")]
fn get_dataset_activity(
    dataset_id : u32,
) -> Option<Vec<DateMetrics>> {
    DATASET_VALUES.with(|map| {
        match map.borrow().get(&dataset_id) {
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

#[query(name = "getDatasetQueryActivity", composite = true)]
fn get_dataset_query_activity(
    dataset_id : u32,
) -> Vec<DateMetrics> {
    QUERIES.with(|map| {
        map.borrow()
            .iter()
            // .filter(|(&id, &query): (&u32, &Query)| query.query_meta.dataset_id == dataset_id)
            .filter(|(_, query)| query.query_meta.dataset_id == dataset_id)
            .group_by(|(_, query)| (query.timestamp / 86_400_000_000) * 86_400_000_000 )
            .into_iter()
            .map(|(k, v)| DateMetrics {date: k, value: v.count() as u32})
            .collect::<Vec<DateMetrics>>()
    })
}

async fn get_dataset_athorized_columns(dataset_id : u32) -> (Vec<u8>, bool) {
    let canister_id: &str = option_env!("CANISTER_ID_fractional_NFT").expect("Could not decode the principal of NFT canister.");
    let access_request: Vec<NftMetadata> =
        ic_cdk::call::<(u32, Principal), (Vec<NftMetadata>, )>(
            Principal::from_text(canister_id).expect("Could not decode the principal."),
            &"getUserDatasetAccess".to_string(),
            (dataset_id, ic_cdk::api::caller())
        ).await.unwrap().0;
    if access_request.len()>=1 {
        (access_request
            .iter()
            .map(|x| x.dimensionRestrictList.clone())
            .flatten()
            .unique()
            .collect::<Vec<u8>>()
        , access_request[0].isGdrpEnabled)
    } else {
        (vec![], false)
    }
}

#[update(name = "getAnalytics")]
async fn get_analytics(query: QueryInput) -> Result<AnalyticsSuperType, String> {
    // Check NFT ownership
    let (authorized, is_gdpr_enabled) = get_dataset_athorized_columns(query.dataset_id).await;
    if authorized.len()>=1 {
        let unauthorized_attributes = query.attributes
            .iter()
            .filter(|x| !authorized.contains(x))
            .cloned()
            .collect::<Vec<u8>>();

        if unauthorized_attributes.len()==0 {
            NEXT_QUERY_ID.with(|current_id| {
                let mut id = current_id.borrow_mut();
                *id += 1;
        
                let query_state = QueryState::Pending;
        
                QUERIES.with(|map| {
                    let now = time();
                    let final_query = Query {
                        timestamp: now,
                        user: ic_cdk::api::caller(),
                        query_meta: query.clone(),
                        query_state: query_state.clone(),
                        is_gdpr: is_gdpr_enabled.clone(),
                        gdpr_limit: 5,
                    };
                    map.borrow_mut().entry(id.clone()).or_insert(final_query);
                    Ok(fetch_analytics(
                        query.dataset_id,
                        query.attributes,
                        query.metrics,
                        query.filters,
                        is_gdpr_enabled,
                        5,
                    ))
                })
            })
        } else {
            return Err("User does not have access to following attributes".to_string());
        }
    } else  {
        Err("User does not own NFT linked to this dataset.".to_string())
    }
}

fn fetch_analytics(
    dataset_id : u32,
    attributes : Vec<u8>,
    metrics : Vec<u8>,
    filters : Vec<(u8, Value)>,
    is_gdpr : bool,
    gdpr_limit : u32
) -> AnalyticsSuperType {
    DATASET_VALUES.with(|map| {
        match map.borrow().get(&dataset_id) {
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

#[query(name = "getDatasetDownload")]
async fn get_dataset_download(dataset_id : u32) -> Vec<DatasetEntry> {
    let (authorized, _) = get_dataset_athorized_columns(dataset_id).await;
    get_data_by_dataset_id(dataset_id, None, Some(authorized))
}

#[query(name = "getDatasetSample")]
fn get_dataset_sample(dataset_id : u32) -> Vec<DatasetEntry> {
    get_data_by_dataset_id(dataset_id, Some(50), None)
}

fn main() {}

#[pre_upgrade]
fn pre_upgrade() {
    let next_dataset_id_copied: u32 = NEXT_DATASET_ID.with(|counter_ref| {
        let reader = counter_ref.borrow();
        *reader
    });
    DATASETS.with(|datasets_ref| {
        DATASET_VALUES.with(|dataset_values_ref| {
            DATASET_OWNERS.with(|dataset_owners_ref| {
                DATASET_PRODUCERS.with(|dataset_producers_ref| {
                    let old_state = StableState {
                        datasets: mem::take(&mut datasets_ref.borrow_mut()),
                        dataset_values: mem::take(&mut dataset_values_ref.borrow_mut()),
                        dataset_owners: mem::take(&mut dataset_owners_ref.borrow_mut()),
                        dataset_producers: mem::take(&mut dataset_producers_ref.borrow_mut()),
                        next_dataset_id: next_dataset_id_copied,
                    };
                    storage::stable_save((old_state,)).unwrap();
                })
            })
        })
    });
}

#[post_upgrade]
fn post_upgrade() {
    let (old_state,): (StableState,) = storage::stable_restore().unwrap();
    DATASETS.with(|datasets_ref| {
        DATASET_VALUES.with(|dataset_values_ref| {
            DATASET_OWNERS.with(|dataset_owners_ref| {
                DATASET_PRODUCERS.with(|dataset_producers_ref| {
                    *datasets_ref.borrow_mut() = old_state.datasets;
                    *dataset_values_ref.borrow_mut() = old_state.dataset_values;
                    *dataset_owners_ref.borrow_mut() = old_state.dataset_owners;
                    *dataset_producers_ref.borrow_mut() = old_state.dataset_producers;
                })
            })
        })
    });
}
