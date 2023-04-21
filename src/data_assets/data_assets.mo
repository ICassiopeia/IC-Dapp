import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import List "mo:base/List";
import Bool "mo:base/Bool";
import Text "mo:base/Text";
import Buffer "mo:base/Buffer";
import Nat32 "mo:base/Nat32";
import Option "mo:base/Option";
import Time "mo:base/Time";

import ExtNonFungible "../toniq-ext/motoko/ext/NonFungible";
import ExtCore "../toniq-ext/motoko/ext/Core";

import T "../libs/types";
import L "../libs/libs";
import A "../libs/admin";

import FNFT "canister:fractional_NFT";

actor DatasetNFT {
  
  private stable var _datasetsState : [(Nat32, T.DatasetConfiguration)] = [];
  private var _datasets : HashMap.HashMap<Nat32, T.DatasetConfiguration> = HashMap.fromIter(_datasetsState.vals(), 0, Nat32.equal, L.hash);
  
  private stable var _datasetOwnersState : [(Principal, [Nat32])] = [];
  private var _datasetOwners : HashMap.HashMap<Principal, [Nat32]> = HashMap.fromIter(_datasetOwnersState.vals(), 0, Principal.equal, Principal.hash);
  
  private stable var _datasetValuesState : [(Nat32, [T.DatasetEntry])] = [];
  private var _datasetValues : HashMap.HashMap<Nat32, [T.DatasetEntry]> = HashMap.fromIter(_datasetValuesState.vals(), 0, Nat32.equal, L.hash);
  
  private stable var _datasetProducersState : [(Nat32, [T.ProducerState])] = [];
  private var _datasetProducers : HashMap.HashMap<Nat32, [T.ProducerState]> = HashMap.fromIter(_datasetProducersState.vals(), 0, Nat32.equal, L.hash);
  
  // private stable var _mintingAuthority : Principal = Principal.fromText(CanisterIds.serviceCanisterId);
  private stable var _nextDatasetId : Nat32  = 0;

  //State functions
  system func preupgrade() {
    _datasetsState := Iter.toArray(_datasets.entries());
    _datasetValuesState := Iter.toArray(_datasetValues.entries());
    _datasetProducersState := Iter.toArray(_datasetProducers.entries());
  };
  system func postupgrade() {
    _datasetsState := [];
    _datasetValuesState := [];
    _datasetProducersState := [];
  };

  // CREATE Dataset
  public shared({caller}) func createDataSet(request: T.DatasetCreateRequest) : async Nat32 {
		_nextDatasetId := _nextDatasetId + 1;
    assert(L._exists<Nat32, T.DatasetConfiguration>(_datasets, _nextDatasetId) == false);
    // Create dataset
    let _datasetConfig = {
      name=request.datasetConfig.name;
      assetId=request.datasetConfig.assetId;
      dimensions=request.datasetConfig.dimensions;
      isActive=true;
      category=request.category;
      createdAt=Time.now();
      updatedAt=Time.now();
    };
		_datasets.put(_nextDatasetId, _datasetConfig);
    switch(_datasetOwners.get(caller)) {
      case (?_list) {
        var _ownerList: Buffer.Buffer<Nat32> = Buffer.fromArray<Nat32>(_list);
        _ownerList.add(_nextDatasetId);
        _datasetOwners.put(caller, Buffer.toArray(_ownerList))
        };
      case (_) {_datasetOwners.put(caller, [_nextDatasetId])};
    };
    // Configure init producer
		_datasetProducers.put(_nextDatasetId, [{id=caller; records=0; isEnabled=true;}]);
    _nextDatasetId
	};

  // DELETE Dataset
  public shared({caller}) func deleteDataSet(datasetId: Nat32) : async () {
    // assert(await FNFT.isOwner(caller, datasetId)); // Ownership
    assert(L._exists<Nat32, T.DatasetConfiguration>(_datasets, _nextDatasetId) == false);
		_datasets.delete(datasetId);
		_datasetProducers.delete(datasetId);
  };

  // Producer auth
  public shared({caller}) func getProducers(datasetId : Nat32) : async (?[T.ProducerState]) {
    _datasetProducers.get(datasetId)
	};

  public shared({caller}) func isUserProducer(datasetId : Nat32) : async (Bool) {
    switch(_datasetProducers.get(datasetId)) {
      case (?_producers) Option.isSome(Array.find<T.ProducerState>(_producers, func(t) { return (Principal.equal(t.id, caller) == true) }));
      case (_) false;
    };
	};

  public shared({caller}) func updateProducerList(datasetId : Nat32, user: Principal, mode: T.UpdateMode) : async () {
    // assert(await FNFT.isOwner(caller, datasetId));
    let newEntry:T.ProducerState = {id=user; records=0; isEnabled=true;};
    switch(_datasetProducers.get(datasetId)) {
      case (?_entryList) {
        let filteredArray = Array.filter<T.ProducerState>(_entryList, func(t) { return (Principal.equal(t.id, user) == false) } );
        if((mode == #Add) and Nat.notEqual(filteredArray.size(), _entryList.size())) {
          _datasetProducers.put(datasetId, List.toArray(List.push<T.ProducerState>(newEntry, List.fromArray(filteredArray))));
        } else {
          _datasetProducers.put(datasetId, filteredArray);
        };
      };
      case (_) {
        if(mode == #Add) {
          _datasetProducers.put(datasetId, Array.make<T.ProducerState>(newEntry));
        };
      };
    };
	};

  // READ Dataset
  public query func getDatasetByDatasetId(datasetId : Nat32) : async (?T.DatasetConfiguration) {
    _datasets.get(datasetId);
	};

  public query({caller}) func getManyDatasets(ids : [Nat32]) : async ([(Nat32, T.DatasetConfiguration)]) {
    var res = Buffer.Buffer<(Nat32, T.DatasetConfiguration)>(1);
    for(datasetId in Iter.fromArray(ids)) {
      switch(_datasets.get(datasetId)) {
        case (?_datasetConfig) res.add((datasetId, _datasetConfig));
        case (_) {};
      };
    };
    Buffer.toArray(res)
	};

  public query({caller}) func getUserDatasets(userId: Principal) : async ([Nat32]) {
    switch(_datasetOwners.get(userId)) {
      case (?_datasets) {
        _datasets;
      };
      case (_) {
        []
      };
    };
	};

  public query({caller}) func searchDataset(search: Text) : async ([Nat32]) {
    // TODO: implement
    [1]
	};

  // READ Values
  public query({caller}) func getUserDataByDatasetId(datasetId : Nat32) : async ([T.DatasetEntry]) {
    switch(_datasetValues.get(datasetId)) {
      case (?_entryList) {
        Array.filter<T.DatasetEntry>(_entryList, func(t) { return T.RecordKey.equal(t.id, #user(caller)) } );
      };
      case (_) {
        []
      };
    };
	};

  public query func getDatasetEntryCounts(datasetIds: [Nat32]) : async [(Nat32, Nat)] {
    let idList = List.fromArray(datasetIds);
    let isInList = func (x : Nat32, y: [T.DatasetEntry]) : ?[T.DatasetEntry] {if(List.some<Nat32>(idList, func (z: Nat32): Bool = (Nat32.equal(x, z)))) ?y else null };
    let filteredList = HashMap.mapFilter<Nat32, [T.DatasetEntry], [T.DatasetEntry]>(_datasetValues, Nat32.equal, L.hash, isInList);
    var res = Buffer.Buffer<(Nat32, Nat)>(1);
    for(item in filteredList.entries()) {
      res.add((item.0, item.1.size()));
    };
    Buffer.toArray(res)
	};

  // UPDATE Values
  private func putEntry(caller: Principal,datasetId: Nat32, datasetValue: T.DatasetEntryInput, mode: T.UpdateMode) : () {
    let _entry: T.DatasetEntry = {
      id=datasetValue.id;
      producer=caller;
      values=datasetValue.values;
      createdAt=Time.now();
      updatedAt=Time.now();
    };
    switch(_datasetValues.get(datasetId)) {
      case (?_entryList) {
        let filterFn = func(t: T.DatasetEntry): Bool { return T.RecordKey.equal(t.id, _entry.id)};
        let filteredArray = Array.filter<T.DatasetEntry>(_entryList, filterFn);
        if(mode == #Add) {
          _datasetValues.put(datasetId, List.toArray(List.push<T.DatasetEntry>(_entry, List.fromArray(filteredArray))));
        } else {
          _datasetValues.put(datasetId, filteredArray);
        };
      };
      case (_) {
        if(mode == #Add) {
          _datasetValues.put(datasetId, Array.make<T.DatasetEntry>(_entry));
        };
      };
    };
  };
 
  public shared({caller}) func putManyEntries(datasetId: Nat32, datasetValues: [T.DatasetEntryInput]) : () {
    for(_entry in Iter.fromArray(datasetValues)) {
      putEntry(caller, datasetId, _entry, #Add);
    };
  };

  // DELETE Values
  public shared({caller}) func deleteUserEntry(datasetId : Nat32) : async Bool {
    switch(_datasetValues.get(datasetId)) {
      case (?_entryList) {
        let filteredArray = Array.filter<T.DatasetEntry>(_entryList, func(t) { return T.RecordKey.equal(t.id, #user(caller))});
        if(Nat.notEqual(filteredArray.size(), _entryList.size())) {
          _datasetValues.put(datasetId, filteredArray);
          true
        } else false
      };
      case (_) false;
    };
	};

  // GDPR - Data Protection
  public shared({caller}) func deleteAllEntriesOfUser(datasetId : Nat32) : async Bool {
    switch(_datasetValues.get(datasetId)) {
      case (?_entryList) {
        let filteredArray = Array.filter<T.DatasetEntry>(_entryList, func(t) { return T.RecordKey.equal(t.id, #user(caller))} );
        if(Nat.notEqual(filteredArray.size(), _entryList.size())) {
          _datasetValues.put(datasetId, filteredArray);
          true
        } else false
      };
      case (_) false;
    };
	};

  // Analytical functions
  public query({caller}) func getDataByDatasetId(datasetId : Nat32) : async (?[T.DatasetEntry]) {
    _datasetValues.get(datasetId)
	};

  public query({caller}) func getRowsByDatasetId(datasetId : Nat32, rows: Int) : async (?T.DatasetEntry) {
    // let _entries = _datasetValues.get(datasetId);
    switch (_datasetValues.get(datasetId)) {
      case(?_entries) Iter.fromArray<T.DatasetEntry>(_entries).next();
      case(_) null
    };
	};

  public query func getProducersStats(datasetId : Nat32) : async [(Principal, Nat)] {
    switch(_datasetValues.get(datasetId)) {
      case (?_values) {
        let grouped: Buffer.Buffer<Buffer.Buffer<T.DatasetEntry>> = Buffer.groupBy<T.DatasetEntry>(Buffer.fromArray(_values), func (x, y) { x.producer == y.producer });
        let stats = Buffer.map<Buffer.Buffer<T.DatasetEntry>, (Principal, Nat)>(grouped, func (x: Buffer.Buffer<T.DatasetEntry>) { ( Buffer.first(x).producer, x.size()) });
        Buffer.toArray(stats)
      };
      case (_) [];
    };
	};

  public query({caller}) func getGDPRAggregatedDataset(datasetId : Nat32, attributeId : Nat32, metricId : Nat32) : async ([(T.Value, {count: Nat32; sum: Nat32})]) {
    let limit:Nat32 = 5;
    let findAttribute = func(val : T.DatasetValue) : (Bool) {Nat32.equal(val.dimensionId, attributeId)};
    let findMetric = func(val : T.DatasetValue) : (Bool) {Nat32.equal(val.dimensionId, metricId)};
    let init : [(T.Value, {count: Nat32; sum: Nat32})] = [];
    let result: HashMap.HashMap<T.Value, {count: Nat32; sum: Nat32}> = HashMap.fromIter(init.vals(), 0, T.Value.equal, T.Value.hash);
    switch(_datasetValues.get(datasetId)) {
      case (?_entries) {
        for(_entry in Iter.fromArray(_entries)) {
          switch(Array.find(_entry.values, findAttribute)) { // Find attribute
            case(?_att) {
              switch(Array.find(_entry.values, findMetric)) { // Find metric
                case(?_met) {
                  switch(result.get(_att.value)) {
                    case(?_res) {
                      switch(_met.value) {
                        case(#metric(val)) result.put(_att.value, {count=_res.count+1; sum=_res.sum+val});
                        case(#attribute(val)) result.put(_att.value, {count=_res.count+1; sum=_res.sum});
                      };
                    };
                    case(_) {
                      switch(_met.value) {
                        case(#metric(val)) result.put(_att.value, {count=1; sum=val});
                        case(#attribute(val)) result.put(_att.value, {count=1; sum=0});
                      };
                    };
                  };
                };
                case(_) {};
              };
            };
            case(_) {};
          };
        };
      };
      case (_) {};
    };

    let resArray = Iter.toArray<(T.Value, {count: Nat32; sum: Nat32})>(result.entries());
    Array.filter<(T.Value, {count: Nat32; sum: Nat32})>(resArray, func(val : (T.Value, {count: Nat32; sum: Nat32})) : (Bool) {Nat32.less(val.1.count, limit)})
	};


  // private func groupByAttribute(attributes : [Nat32], metrics : [Nat32]) : (Buffer.Buffer<Buffer.Buffer<T.DatasetEntry>>) {
  //   if(attributes.size() == 1) {
  //     return Buffer.groupBy<T.DatasetEntry>(Buffer.fromArray(_values), func (x, y) { x.producer == y.producer });
  //   }
  //   return groupByAttribute()
  // };

  private func isSameAttributes(attributes : [Nat32], x : T.DatasetEntry, y: T.DatasetEntry) : (Bool) {
    // Array.foldLeft<Nat32, Bool>(attributes, true, func(acc, _att) {
    //   acc and (Array.find(x.values, func(val : T.DatasetValue) : (Bool) {Nat32.equal(val.dimensionId, _att)}) == Array.find(y.values, func(val : T.DatasetValue) : (Bool) {Nat32.equal(val.dimensionId, _att)}))
    // })
    true
  };

  public query({caller}) func fetchAnalytics(
    datasetId : Nat32,
    attributes : [Nat32],
    metrics : [Nat32]
  // ) : async ([(T.Value, {count: Nat32; sum: Nat32})]) {
  ) : async ([T.AnayticsType]) {
    switch(_datasetValues.get(datasetId)) {
      case (?_entries) {
        // Filter data
        // Prepare data (hash column casting?)
        // Buffer data
        let buffered = Buffer.fromArray<T.DatasetEntry>(_entries);
        // Aggregate
        let groupingFn = func (x: T.DatasetEntry, y: T.DatasetEntry): Bool { isSameAttributes(attributes, x, y) };
        let grouped = Buffer.groupBy<T.DatasetEntry>(buffered, groupingFn);
        let aggregated = Buffer.map<Buffer.Buffer<T.DatasetEntry>, T.AnayticsType>(grouped, func (x: Buffer.Buffer<T.DatasetEntry>): T.AnayticsType { 
            return {
              attributes=Array.mapFilter<T.DatasetValue, T.Value>(Buffer.first(x).values, func(_val: T.DatasetValue): ?T.Value = if(Buffer.contains<Nat32>(Buffer.fromArray<Nat32>(attributes), _val.dimensionId, Nat32.equal)) ? _val.value else null);
              count=x.size();
              // metrics : Buffer.foldLeft<Nat32, Bool>(attributes, true, func(acc, _att) {acc+1})
            }
          });
        Buffer.toArray(aggregated)
        // GDPR
        // Render
        // let rendered = Buffer.map(grouped, )
      };
      case (_) [];
    };
  };

//   public query({caller}) func fetchAnalytics2(
//     datasetId : Nat32,
//     attributes : [Nat32],
//     metrics : [Nat32]
//   // ) : async ([(T.Value, {count: Nat32; sum: Nat32})]) {
//   ) : async ([[T.DatasetValue]]) {
//     switch(_datasetValues.get(datasetId)) {
//       case (?_entries) {
//         // Filter data
//         // Prepare data (hash column casting?)
//         // Buffer data
//         let buffered = Buffer.map<T.DatasetEntry, T.SelectedEntry>(Buffer.fromArray<T.DatasetEntry>(_entries), func(x: T.DatasetEntry) {return {
//             producer=x.producer;
//             columnHash=;
//             values= Array.mapFilter(x.values, func(y: datasetValue) {});
//           }});
//         // Aggregate
//         let groupingFn = func (x: T.DatasetEntry, y: T.DatasetEntry): Bool { isSameAttributes(attributes, x, y) };
//         let grouped: Buffer.Buffer<Buffer.Buffer<T.DatasetEntry>> = Buffer.groupBy<T.DatasetEntry>(buffered, groupingFn);
//         let fn = func(x: Buffer.Buffer<T.DatasetEntry>): [T.DatasetValue] {
//           Buffer.toArray<T.DatasetValue>(
//             Buffer.mapFilter<T.DatasetEntry, T.DatasetValue>(x, func(y: T.DatasetEntry): ?T.DatasetValue {
//               Array.find<T.DatasetValue>(y.values, func(z: T.DatasetValue): Bool {z.dimensionId == 1})
//               }
//             )
//           )
//         };
//         Buffer.toArray(Buffer.map<Buffer.Buffer<T.DatasetEntry>, [T.DatasetValue]>(grouped, fn))
//       };
//       case (_) [];
//     };
//   };

//   public query({caller}) func fetchAnalytics3(
//     datasetId : Nat32,
//     attributes : [Nat32],
//     metrics : [Nat32]
//   // ) : async ([(T.Value, {count: Nat32; sum: Nat32})]) {
//   ) : async (Text) {
//     let buffer = Buffer.fromArray<Nat>([]);
//     buffer.add(2);
//     buffer.add(1);
//     buffer.add(2);
//     buffer.add(6);
//     buffer.add(5);
//     buffer.add(4);
//     buffer.add(5);

//     let grouped = Buffer.groupBy<Nat>(buffer, func (x, y) { x == y });
//     Buffer.toText<Buffer.Buffer<Nat>>(grouped, func buf = Buffer.toText(buf, Nat.toText)); // => [[1], [2, 2], [4], [5, 5]]
//   };
}
