export const idlFactory = ({ IDL }) => {
  const SalesTypes = IDL.Variant({
    'marketplace' : IDL.Null,
    'gift' : IDL.Null,
  });
  const SellOrderInput = IDL.Record({
    'nftToken' : IDL.Nat32,
    'secret' : IDL.Text,
    'orderType' : SalesTypes,
    'toDate' : IDL.Int,
    'price' : IDL.Nat32,
  });
  const BuyOrderInput = IDL.Record({
    'purchasePrice' : IDL.Nat32,
    'assetId' : IDL.Text,
  });
  const Result_1 = IDL.Variant({ 'ok' : IDL.Text, 'err' : IDL.Text });
  const Result_2 = IDL.Variant({
    'ok' : IDL.Tuple(IDL.Nat32, IDL.Principal),
    'err' : IDL.Text,
  });
  const SalesStats = IDL.Record({
    'assetId' : IDL.Text,
    'count' : IDL.Nat32,
    'price' : IDL.Nat32,
  });
  const BuyOrder = IDL.Record({
    'purchasePrice' : IDL.Nat32,
    'assetId' : IDL.Text,
    'createdAt' : IDL.Int,
    'updatedAt' : IDL.Int,
    'buyer' : IDL.Principal,
  });
  const SellOrder = IDL.Record({
    'nftToken' : IDL.Nat32,
    'collectionId' : IDL.Nat32,
    'assetId' : IDL.Text,
    'createdAt' : IDL.Int,
    'secret' : IDL.Text,
    'seller' : IDL.Principal,
    'orderType' : SalesTypes,
    'toDate' : IDL.Int,
    'updatedAt' : IDL.Int,
    'fromDate' : IDL.Int,
    'price' : IDL.Nat32,
  });
  const SellOrderType = IDL.Record({ 'id' : IDL.Nat32, 'order' : SellOrder });
  const SalesContractInput = IDL.Record({
    'buyOrder' : BuyOrder,
    'orderType' : SalesTypes,
    'sellRef' : SellOrderType,
    'offerId' : IDL.Nat32,
  });
  const CreatorSalesStats = IDL.Record({
    'assetId' : IDL.Text,
    'sales' : IDL.Nat32,
    'commissions' : IDL.Nat32,
  });
  const SalesContractStatus = IDL.Variant({
    'pending' : IDL.Null,
    'blocked' : IDL.Null,
    'approved' : IDL.Null,
    'rejected' : IDL.Null,
  });
  const TransactionType = IDL.Variant({
    'base' : IDL.Null,
    'mint' : IDL.Null,
    'commission' : IDL.Null,
  });
  const Transaction = IDL.Record({
    'to' : IDL.Principal,
    'transactionType' : TransactionType,
    'value' : IDL.Nat32,
    'from' : IDL.Principal,
    'executionDate' : IDL.Int,
  });
  const SalesContract = IDL.Record({
    'status' : SalesContractStatus,
    'buyOrder' : BuyOrder,
    'purchasePrice' : IDL.Nat32,
    'seller' : IDL.Principal,
    'nftId' : IDL.Nat32,
    'buyer' : IDL.Principal,
    'transactions' : IDL.Vec(Transaction),
    'executionDate' : IDL.Int,
    'sellOrder' : SellOrder,
    'executionType' : SalesTypes,
    'parties' : IDL.Vec(IDL.Principal),
  });
  const SalesContractType = IDL.Record({
    'id' : IDL.Nat32,
    'contract' : SalesContract,
  });
  const TopSalesStats = IDL.Record({
    'count' : IDL.Nat32,
    'twoWeeksAgo' : IDL.Nat32,
    'lastWeek' : IDL.Nat32,
  });
  const Result = IDL.Variant({ 'ok' : IDL.Nat32, 'err' : IDL.Text });
  return IDL.Service({
    'batchSellOrder' : IDL.Func(
        [IDL.Principal, IDL.Vec(SellOrderInput)],
        [],
        [],
      ),
    'buyOrder' : IDL.Func(
        [IDL.Text, IDL.Principal, BuyOrderInput],
        [Result_1],
        [],
      ),
    'executeBuyOrder' : IDL.Func([IDL.Text], [Result_2], []),
    'getAssetStats' : IDL.Func([IDL.Text], [SalesStats], ['query']),
    'getBuyOrder' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(IDL.Text, SalesContractInput))],
        ['query'],
      ),
    'getCreatorAssetsStats' : IDL.Func(
        [IDL.Vec(IDL.Text)],
        [IDL.Vec(CreatorSalesStats)],
        ['query'],
      ),
    'getManyAssetStats' : IDL.Func(
        [IDL.Vec(IDL.Text)],
        [IDL.Vec(SalesStats)],
        ['query'],
      ),
    'getSalesOrder' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(IDL.Nat32, SalesContract))],
        ['query'],
      ),
    'getSalesOrderByAssetId' : IDL.Func(
        [IDL.Text],
        [IDL.Vec(SalesContractType)],
        ['query'],
      ),
    'getSalesOrderByContractId' : IDL.Func(
        [IDL.Nat32],
        [IDL.Opt(SalesContract)],
        ['query'],
      ),
    'getSalesOrderByNftId' : IDL.Func(
        [IDL.Nat32],
        [IDL.Vec(IDL.Tuple(IDL.Nat32, SalesContract))],
        ['query'],
      ),
    'getSalesOrderByUserId' : IDL.Func(
        [],
        [IDL.Vec(SalesContractType)],
        ['query'],
      ),
    'getSellOrderByAssetId' : IDL.Func(
        [IDL.Text],
        [IDL.Vec(SellOrderType)],
        ['query'],
      ),
    'getSellOrderByCollectionId' : IDL.Func(
        [IDL.Nat32],
        [IDL.Vec(IDL.Tuple(IDL.Nat32, SellOrder))],
        ['query'],
      ),
    'getSellOrderByUserId' : IDL.Func(
        [IDL.Principal],
        [IDL.Vec(SellOrderType)],
        ['query'],
      ),
    'getSellOrders' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(IDL.Nat32, SellOrder))],
        ['query'],
      ),
    'getTopSales' : IDL.Func(
        [],
        [IDL.Vec(IDL.Tuple(IDL.Text, TopSalesStats))],
        ['query'],
      ),
    'getTrendingAssests' : IDL.Func([], [], ['query']),
    'getUserSalesStats' : IDL.Func([], [], ['query']),
    'redeemGift' : IDL.Func([IDL.Principal, IDL.Text], [Result_1], []),
    'resetDatastore' : IDL.Func([], [], ['query']),
    'sellOrder' : IDL.Func([IDL.Principal, SellOrderInput], [Result], []),
  });
};
export const init = ({ IDL }) => { return []; };
