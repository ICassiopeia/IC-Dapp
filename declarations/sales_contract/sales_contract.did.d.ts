import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';

export interface BuyOrder {
  'purchasePrice' : number,
  'assetId' : string,
  'createdAt' : bigint,
  'updatedAt' : bigint,
  'buyer' : Principal,
}
export interface BuyOrderInput { 'purchasePrice' : number, 'assetId' : string }
export interface CreatorSalesStats {
  'assetId' : string,
  'sales' : number,
  'commissions' : number,
}
export type Result = { 'ok' : number } |
  { 'err' : string };
export type Result_1 = { 'ok' : string } |
  { 'err' : string };
export type Result_2 = { 'ok' : [number, Principal] } |
  { 'err' : string };
export interface SalesContract {
  'status' : SalesContractStatus,
  'buyOrder' : BuyOrder,
  'purchasePrice' : number,
  'seller' : Principal,
  'nftId' : number,
  'buyer' : Principal,
  'transactions' : Array<Transaction>,
  'executionDate' : bigint,
  'sellOrder' : SellOrder,
  'executionType' : SalesTypes,
  'parties' : Array<Principal>,
}
export interface SalesContractInput {
  'buyOrder' : BuyOrder,
  'orderType' : SalesTypes,
  'sellRef' : SellOrderType,
  'offerId' : number,
}
export type SalesContractStatus = { 'pending' : null } |
  { 'blocked' : null } |
  { 'approved' : null } |
  { 'rejected' : null };
export interface SalesContractType { 'id' : number, 'contract' : SalesContract }
export interface SalesStats {
  'assetId' : string,
  'count' : number,
  'price' : number,
}
export type SalesTypes = { 'marketplace' : null } |
  { 'gift' : null };
export interface SellOrder {
  'nftToken' : number,
  'collectionId' : number,
  'assetId' : string,
  'createdAt' : bigint,
  'secret' : string,
  'seller' : Principal,
  'orderType' : SalesTypes,
  'toDate' : bigint,
  'updatedAt' : bigint,
  'fromDate' : bigint,
  'price' : number,
}
export interface SellOrderInput {
  'nftToken' : number,
  'secret' : string,
  'orderType' : SalesTypes,
  'toDate' : bigint,
  'price' : number,
}
export interface SellOrderType { 'id' : number, 'order' : SellOrder }
export interface TopSalesStats {
  'count' : number,
  'twoWeeksAgo' : number,
  'lastWeek' : number,
}
export interface Transaction {
  'to' : Principal,
  'transactionType' : TransactionType,
  'value' : number,
  'from' : Principal,
  'executionDate' : bigint,
}
export type TransactionType = { 'base' : null } |
  { 'mint' : null } |
  { 'commission' : null };
export interface _SERVICE {
  'batchSellOrder' : ActorMethod<[Principal, Array<SellOrderInput>], undefined>,
  'buyOrder' : ActorMethod<[string, Principal, BuyOrderInput], Result_1>,
  'executeBuyOrder' : ActorMethod<[string], Result_2>,
  'getAssetStats' : ActorMethod<[string], SalesStats>,
  'getBuyOrder' : ActorMethod<[], Array<[string, SalesContractInput]>>,
  'getCreatorAssetsStats' : ActorMethod<
    [Array<string>],
    Array<CreatorSalesStats>
  >,
  'getManyAssetStats' : ActorMethod<[Array<string>], Array<SalesStats>>,
  'getSalesOrder' : ActorMethod<[], Array<[number, SalesContract]>>,
  'getSalesOrderByAssetId' : ActorMethod<[string], Array<SalesContractType>>,
  'getSalesOrderByContractId' : ActorMethod<[number], [] | [SalesContract]>,
  'getSalesOrderByNftId' : ActorMethod<
    [number],
    Array<[number, SalesContract]>
  >,
  'getSalesOrderByUserId' : ActorMethod<[], Array<SalesContractType>>,
  'getSellOrderByAssetId' : ActorMethod<[string], Array<SellOrderType>>,
  'getSellOrderByCollectionId' : ActorMethod<
    [number],
    Array<[number, SellOrder]>
  >,
  'getSellOrderByUserId' : ActorMethod<[Principal], Array<SellOrderType>>,
  'getSellOrders' : ActorMethod<[], Array<[number, SellOrder]>>,
  'getTopSales' : ActorMethod<[], Array<[string, TopSalesStats]>>,
  'getTrendingAssests' : ActorMethod<[], undefined>,
  'getUserSalesStats' : ActorMethod<[], undefined>,
  'redeemGift' : ActorMethod<[Principal, string], Result_1>,
  'resetDatastore' : ActorMethod<[], undefined>,
  'sellOrder' : ActorMethod<[Principal, SellOrderInput], Result>,
}
