
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Hash "mo:base/Hash";

import ExtNonFungible "../toniq-ext/motoko/ext/NonFungible";
import ExtCore "../toniq-ext/motoko/ext/Core";

module {

  // 
  // Data Assets: START
  //
  public type DatasetCreateRequest = {
    metadataNFT: Blob;
    category: [Text];
    datasetConfig: DatasetConfigurationInput;
  };

  public type DimensionType = {
    #Binary;
    #Categorical: [Text];
    #Numerical;
  };

  public type DatasetConfiguration = {
    name : Text;
    assetId : Text;
    dimensions: [DatasetDimension];
    isActive: Bool;
    category: [Text];
    createdAt: Int;
    updatedAt: Int;
  };

  public type DatasetConfigurationInput = {
    name : Text;
    assetId : Text;
    dimensions: [DatasetDimension];
  };

  public type DatasetDimension = {
    dimensionId : Nat32;
    title : Text;
    dimensionType : DimensionType;
  };

  public type RecordKey = {
    #user : Principal;
    #id : Nat32;
  };

  public module RecordKey = {
    public func equal(x : RecordKey, y : RecordKey) : Bool {
      return switch(x) {
        case(#user(x1)) switch(y) {
            case(#user(y1)) (Principal.equal(x1, y1) == false);
            case(#id(_)) true;
          };
        case(#id(x2))  switch(y) {
          case(#user(_)) true;
          case(#id(y2)) (Nat32.equal(x2, y2) == false);
        };
      };
    };
    // public func hash(x : RecordKey) : Hash.Hash {
    //   return x;
    // };
  };

  public type Value = {
    #metric : Nat32;
    #attribute : Text;
  };

  public module Value = {
    public func equal(x : Value, y : Value) : Bool {
      return switch(x) {
        case(#metric(x1)) switch(y) {
            case(#metric(y1)) (Nat32.equal(x1, y1) == false);
            case(#attribute(_)) true;
          };
        case(#attribute(x2))  switch(y) {
          case(#metric(_)) true;
          case(#attribute(y2)) (Text.equal(x2, y2) == false);
        };
      };
    };
    public func hash(x : Value) : Hash.Hash {
      return switch(x) {
        case(#metric(x1)) return x1;
        case(#attribute(x2)) return Text.hash(x2);
      };
    };
  };

  public type DatasetEntry = {
    id : RecordKey;
    values : [DatasetValue];
    createdAt: Int;
    updatedAt: Int;
  };

  public type DatasetEntryInput = {
    id : RecordKey;
    values : [DatasetValue];
  };

  public type DatasetValue = {
    dimensionId : Nat32;
    value : Value;
  };

  public type DatasetType = {
    datasetId : Nat32;
    datasetConfig: DatasetConfiguration;
    entries : [DatasetEntry];
  };

  // 
  // Data Assets: END
  //

  public type UpdateMode = {
    #Add;
    #Remove;
  };

  // 
  // F-NFT: START
  //
  public type Metadata = {
    name: Text;
    description: Text;
    dataAssetId: Nat32;
    isEnabled: Bool;
    price: Nat32;
    supply: Nat32;
    timeLimitSeconds: Nat32;
    dimensionRestrictList: [Nat32];
    isGdrpEnabled: Bool;
    createdAt: Int;
    updatedAt: Int;
  };

  public type MintRequest = {
    to : ExtCore.User;
    metadata : Metadata;
  };

  public type OfferNftInfo = {
    id : ExtCore.TokenIndex;
    owner : ExtCore.AccountIdentifier;
    metadata : Metadata;
  };

  public type NftStats = {
    supply : ExtCore.Balance;
    left : ExtCore.Balance;
  };

  public let nullNftStats: NftStats = {
    supply= 0;
    left= 0;
  };

  // 
  // F-NFT: END
  //


  // 
  // Sales contracts: START
  //
  public type BuyOrder = {
    buyer: ExtCore.AccountIdentifier;
    offerNftId: ExtCore.TokenIndex;
    purchasePrice: Nat32;
    createdAt: Int;
    updatedAt: Int;
  };

  public type BuyOrderInput = {
    offerNftId: ExtCore.TokenIndex;
    purchasePrice: Nat32;
  };

  public type SalesStats = {
    offerNftId: ExtCore.TokenIndex;
    count: Nat32;
    price: Nat32;
  };

  public type SalesContractStatus = {
    #pending;
    #blocked;
    #rejected;
    #approved;
  };

  public type SalesContract = {
    buyer: ExtCore.AccountIdentifier;
    seller: ExtCore.AccountIdentifier;
    nftId:Nat32;
    purchasePrice: Nat32;
    status: SalesContractStatus;
    executionDate: Int;
    transactions: [Transaction];
    buyOrder: BuyOrder;
  };

  public type SalesContractType = {
    id: Nat32;
    contract: SalesContract;
  };

  public type Transaction = {
    from: ExtCore.AccountIdentifier;
    to: ExtCore.AccountIdentifier;
    value: Nat32;
    transactionType: TransactionType;
    executionDate: Int;
  };

  public type TransactionType = {
    #base;
    #commission;
    #mint;
  };

  public type TopSalesStats = {
    lastWeek: Nat32;
    twoWeeksAgo: Nat32;
    count: Nat32;
  };

  public type SalesContractInput = {
    offerId: Nat32;
    buyOrder: BuyOrder;
  };

  public type CreatorSalesStats = {
    offerNftId: ExtCore.TokenIndex;
    sales: Nat32;
    commissions: Nat32;
  };
  // 
  // Sales contracts: END
  //

}