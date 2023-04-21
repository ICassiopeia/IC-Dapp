use std::fmt;
use std::fmt::Write;
use std::collections::{HashMap};
use candid::{CandidType, Principal};
use serde::{Deserialize, Serialize};

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DatasetConfiguration {
    pub name : String,
    pub asset_id : String,
    pub dimensions: Vec<DatasetDimension>,
    pub is_active: bool,
    pub category: Vec<String>,
    pub created_at: i128,
    pub updated_at: i128,
}

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DatasetDimension {
    pub dimension_id : u32,
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
    pub created_at : i128,
    pub updated_at : i128,
}

#[derive(CandidType, Copy, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum RecordKey {
    User(Principal),
    Id(u32),
}
#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DatasetValue {
    pub dimension_id : u32,
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
    pub asset_id : String,
    pub dimensions : Vec<DatasetDimension>,
}

#[derive(CandidType, Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ProducerState {
    pub id : Principal,
    pub is_enabled: bool,
    pub records: u32,
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
    pub metrics : HashMap::<u32, u32>,
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

