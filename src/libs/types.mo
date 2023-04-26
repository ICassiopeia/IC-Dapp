
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Hash "mo:base/Hash";

import ExtNonFungible "../toniq-ext/motoko/ext/NonFungible";
import ExtCore "../toniq-ext/motoko/ext/Core";

module {

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
    dimensionRestrictList: [Nat8];
    isGdrpEnabled: Bool;
    createdAt: Int;
    updatedAt: Int;
  };

  public type MetadataSmall = {
    dataAssetId: Nat32;
    isEnabled: Bool;
    price: Nat32;
    supply: Nat32;
    timeLimitSeconds: Nat32;
    dimensionRestrictList: [Nat8];
    isGdrpEnabled: Bool;
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