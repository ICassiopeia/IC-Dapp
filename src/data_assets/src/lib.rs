use std::fmt;
use std::collections::HashMap;
use candid::{CandidType, Principal};
use serde::{Deserialize, Serialize};

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DatasetConfiguration {
    pub name : String,
    pub asset_id : String,
    pub description: String,
    pub jupyter_notebook: Option<String>,
    pub dimensions: Vec<DatasetDimension>,
    pub is_active: bool,
    pub category: Vec<String>,
    pub created_at: u64,
    pub updated_at: u64,
}

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DatasetDimension {
    pub dimension_id : u8,
    pub title : String,
    pub dimension_type : DimensionType,
}

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum DimensionType {
    Numerical,
    Binary,
    Categorical(Vec<String>),
    Freetext,
}

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DatasetEntry {
    pub id : RecordKey,
    pub producer : Principal,
    pub values : Vec<DatasetValue>,
    pub created_at : u64,
    pub updated_at : u64,
}

#[derive(CandidType, Copy, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum RecordKey {
    User(Principal),
    Id(u32),
}
#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DatasetValue {
    pub dimension_id : u8,
    pub value : Value,
}

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum Value {
    Metric(u32),
    Attribute(String),
}
impl fmt::Display for Value {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            Value::Attribute(att) => write!(f, "{:?}", att.clone()),
            Value::Metric(met) =>  write!(f, "{:?}", met.to_string()),
        }
    }
}
#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DatasetEntryInput {
    pub id : RecordKey,
    pub values : Vec<DatasetValue>,
}

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DatasetCreateRequest {
    pub metadata_nft : Vec<u8>,
    pub category : Vec<String>,
    pub dataset_config : DatasetConfigurationInput,
}

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DatasetConfigurationInput {
    pub name : String,
    pub description : String,
    pub asset_id : String,
    pub dimensions : Vec<DatasetDimension>,
    pub jupyter_notebook: Option<String>,
}

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ProducerState {
    pub id : Principal,
    pub is_enabled: bool,
}

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct StableState {
    pub datasets: HashMap<u32, DatasetConfiguration>,
    pub dataset_values: HashMap<u32, Vec<DatasetEntry>>,
    pub dataset_owners: HashMap<Principal, Vec<u32>>,
    pub dataset_producers: HashMap<u32, Vec<ProducerState>>,
    pub next_dataset_id: u32,
}

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum UpdateMode {
    Add,
    Remove,
}

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AnalyticsType {
    pub group_key : String,
    pub attributes : Vec<Value>,
    pub metrics : HashMap::<u8, u32>,
    pub count : u32,
}

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AnalyticsSuperType {
    pub analytics : Vec<AnalyticsType>,
    pub counts : (u32, u32, u32, u32, u32),
}

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AnayticsPrep {
    pub att_hash : String,
    pub att : Vec<Value>,
    pub met: Vec<DatasetValue>,
}


#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DateMetrics {
    pub date : u64,
    pub value : u32,
}

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct QueryInput {
    pub dataset_id : u32,
    pub attributes : Vec<u8>,
    pub metrics : Vec<u8>,
    pub filters : Vec<(u8, Value)>,
}
#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Query {
    pub timestamp : u64,
    pub user : Principal,
    pub query_meta : QueryInput,
    pub query_state : QueryState,
    pub is_gdpr : bool,
    pub gdpr_limit : u32,
}

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum QueryState {
    Accepted,
    Pending,
    Rejected(String),
}

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum AnalyticsError {
    Unauthorized,
    TokenExpired,
    Other(String),
}

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct NftMetadata {
    pub name : String,
    pub description : String,
    pub dataAssetId : u32,
    pub isEnabled : bool,
    pub price : u32,
    pub supply : u32,
    pub timeLimitSeconds : u32,
    pub dimensionRestrictList : Vec<u8>,
    pub isGdrpEnabled : bool,
    pub createdAt : u64,
    pub updatedAt : u64,
}
