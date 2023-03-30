import Result "mo:base/Result";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Error "mo:base/Error";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import List "mo:base/List";
import Buffer "mo:base/Buffer";
import Prim "mo:⛔";
import AID "../toniq-ext/motoko/util/AccountIdentifier";

import FNFT "canister:fractional_NFT";
import T "../libs/types";
import L "../libs/libs";
import ExtCore "../toniq-ext/motoko/ext/Core";

actor sales_contracts {

    //State work
    private stable var _buyOrdersState : [(Text, T.SalesContractInput)] = [];
    private var _buyOrders : HashMap.HashMap<Text, T.SalesContractInput> = HashMap.fromIter(_buyOrdersState.vals(), 0,Text.equal, Text.hash);
	
    private stable var _salesContractsState : [(Nat32, T.SalesContract)] = [];
    private var _salesContracts : HashMap.HashMap<Nat32, T.SalesContract> = HashMap.fromIter(_salesContractsState.vals(), 0, Nat32.equal, L.hash);
 
    private stable var _totalCount : Nat32  = 0;
    private stable var _totalSuccessCount : Nat32  = 0;
    private stable var _nextSalesId : Nat32  = 0;

    //State functions
    system func preupgrade() {
        _buyOrdersState := Iter.toArray(_buyOrders.entries());
        _salesContractsState := Iter.toArray(_salesContracts.entries());
    };

    system func postupgrade() {
        _buyOrdersState := [];
        _salesContractsState := [];
    };

    //
    // Buy functions
    //
    public shared({caller}) func buyOrder(transactionId: Text, buyer: Principal, order: T.BuyOrderInput) : async Result.Result<Text, Text> {
        // Check that 1/ offer is available and 2/there are remaining tokens 
        assert(await FNFT.isBuyable(order.offerNftId));
        _nextSalesId := _nextSalesId + 1;
        let finalOrder: T.BuyOrder = {
            buyer= AID.fromPrincipal(buyer, null);
            offerNftId= order.offerNftId;
            purchasePrice= order.purchasePrice;
            createdAt= Time.now();
            updatedAt= Time.now();
        };
        let buyOrderRecord : T.SalesContractInput = {
            offerId= _nextSalesId;
            buyOrder= finalOrder;
            orderType= #marketplace;
        };
        _buyOrders.put(transactionId, buyOrderRecord);
        #ok(transactionId)
    };

    public shared({caller}) func executeBuyOrder(transactionId: Text) : async Result.Result<(Nat32), Text> {
        switch (_buyOrders.get(transactionId)) {
            case (?res) {
                let result = await _executeSalesOrder(res.offerId, res.buyOrder);
                #ok((res.offerId))
            };
            case (_) {
                 #err("No offer matches buy order [ERR0011]");
            };
        };
    };

    //
    // Sales contracts functions
    //

    public query({caller}) func getSalesOrder() : async [(Nat32, T.SalesContract)] {
        Iter.toArray(_salesContracts.entries())
    };

    public query func getSalesOrderByContractId(contractId: Nat32) : async (?T.SalesContract) {
        _salesContracts.get(contractId)
    };

    public query func getSalesOrderByNftId(nftId: Nat32) : async [(Nat32, T.SalesContract)] {
        let isNftId = func (x : Nat32, y: T.SalesContract) : ?T.SalesContract { if (y.nftId == nftId) ?y else null };
        Iter.toArray(HashMap.mapFilter<Nat32, T.SalesContract, T.SalesContract>(_salesContracts, Nat32.equal, L.hash, isNftId).entries())
    };

    public query func getSalesOrderByAssetId(offerNftId: ExtCore.TokenIndex) : async [(T.SalesContractType)] {
        let isAsset = func (x : Nat32, y: T.SalesContract) : ?T.SalesContract { if (y.buyOrder.offerNftId == offerNftId) ?y else null };
        let contracts = Iter.toArray(HashMap.mapFilter<Nat32, T.SalesContract, T.SalesContract>(_salesContracts, Nat32.equal, L.hash, isAsset).entries());
        Array.map<(Nat32, T.SalesContract), T.SalesContractType>(contracts, func(x : Nat32, y: T.SalesContract) { {id=x; contract=y ;} } )
    };

    public query({caller}) func getSalesOrderByUserId() : async [(T.SalesContractType)] {
        let isAssetIds = func (x : Nat32, y: T.SalesContract) : ?T.SalesContract {if(AID.equal(AID.fromPrincipal(caller, null), y.buyer)) ?y else null };
        // let isAssetIds = func (x : Nat32, y: T.SalesContract) : ?T.SalesContract {if(List.some<Principal>(List.fromArray(y.parties), func (z: Principal): Bool = Principal.equal(caller, z))) ?y else null };
        let contracts = Iter.toArray(HashMap.mapFilter<Nat32, T.SalesContract, T.SalesContract>(_salesContracts, Nat32.equal, L.hash, isAssetIds).entries());
        Array.map<(Nat32, T.SalesContract), T.SalesContractType>(contracts, func(x : Nat32, y: T.SalesContract) { {id=x; contract=y ;} } )
    };

    private func _executeSalesOrder(offerId: Nat32, buyOrder: T.BuyOrder) : async T.SalesContract {
        let offerInfo = await FNFT.getManyOfferNftMetdata([buyOrder.offerNftId]);
        let _offer = offerInfo[0];
        let executionDate = Time.now();
        let baseTransaction: T.Transaction = {
            from= buyOrder.buyer;
            to= _offer.owner;
            value= _offer.metadata.price;
            transactionType= #base;
            executionDate= executionDate;
        };

        let finalOffer: T.SalesContract = {
            buyer= buyOrder.buyer;
            seller= _offer.owner;
            nftId= _offer.id;
            purchasePrice= _offer.metadata.price;
            status= #approved;
            executionDate= executionDate;
            transactions=[baseTransaction];
            buyOrder=buyOrder;
        };

        _salesContracts.put(offerId, finalOffer);
        await FNFT.transferFrom(finalOffer.seller, finalOffer.buyer, finalOffer.nftId);
        finalOffer
    };

    //
    // Stats functions
    //

    public query func getUserSalesStats() : async () {
        // TODO
    };

    public query func getTrendingAssests() : async () {
        // TODO
    };


    public query func getTopSales() : async [(ExtCore.TokenIndex, T.TopSalesStats)] {
        let inLast14Days = func (x : Nat32, y: T.SalesContract) : ?T.SalesContract { if ((y.executionDate >= Time.now()-1209600000000000)) ?y else null };
        let lastSalesContracts = HashMap.mapFilter<Nat32, T.SalesContract, T.SalesContract>(_salesContracts, Nat32.equal, L.hash, inLast14Days);
        // let extractPrice = func (x : Nat32, y: T.SalesContract) : (Text, Nat32) { (y.buyOrder.offerNftId, y.purchasePrice) };

        var _aggregatedSales = HashMap.HashMap<ExtCore.TokenIndex, T.TopSalesStats>(0, ExtCore.TokenIndex.equal, ExtCore.TokenIndex.hash);
        for(sale in lastSalesContracts.entries()) {
            let (_, contract) = sale;
            var lastWeek: Nat32 = 0;
            var twoWeeksAgo: Nat32 = 0;
            var count: Nat32 = 1;

            if(Int.greaterOrEqual(contract.executionDate, Time.now()-604800000000000)) lastWeek := contract.purchasePrice
            else twoWeeksAgo := contract.purchasePrice;

            switch (_aggregatedSales.get(contract.buyOrder.offerNftId)) {
                case (?res) {
                    lastWeek := lastWeek + res.lastWeek;
                    twoWeeksAgo := twoWeeksAgo + res.twoWeeksAgo;
                    count := count + res.count;
                };
                case (_) {};
            };
            _aggregatedSales.put((contract.buyOrder.offerNftId, {
                lastWeek=lastWeek;
                twoWeeksAgo=twoWeeksAgo;
                count=count;
            }));
        };
        Iter.toArray(_aggregatedSales.entries())
    };

    // public query func getAssetStats(offerNftId: Text) : async (T.SalesStats) {
    //     let isAsset = func (x : Nat32, y: T.SellOrder) : ?T.SellOrder { if ((y.offerNftId == offerNftId) and (y.orderType == #marketplace)) ?y else null };
    //     let assetOffers = Iter.toArray(HashMap.mapFilter<Nat32, T.SellOrder, T.SellOrder>(_offers, Nat32.equal, L.hash, isAsset).entries());

    //     var minPrice: Nat32 = 0;
    //     if(Nat.greater(assetOffers.size(), 0)) {
    //         let orderMin = func (x: (Nat32, T.SellOrder), y: (Nat32, T.SellOrder)) : ((Nat32, T.SellOrder)) { if(Nat32.less(x.1.price, y.1.price)) x else y };
    //         let bestOffer = Array.foldLeft<(Nat32, T.SellOrder), (Nat32, T.SellOrder)>(assetOffers, assetOffers[0], orderMin);
    //         minPrice := bestOffer.1.price;
    //     };

    //     {
    //         offerNftId= offerNftId;
    //         count= Nat32.fromNat(assetOffers.size());
    //         price= minPrice;
    //     };
    // };

    // public query func getManyAssetStats(assetIds: [Text]) : async [(T.SalesStats)] {
    //     var _res = List.nil<T.SalesStats>();
    //     for(offerNftId in Iter.fromArray(assetIds)) {
    //         let isAsset = func (x : Nat32, y: T.SellOrder) : ?T.SellOrder { if ((y.offerNftId == offerNftId) and (y.orderType == #marketplace)) ?y else null };
    //         let assetOffers = Iter.toArray(HashMap.mapFilter<Nat32, T.SellOrder, T.SellOrder>(_offers, Nat32.equal, L.hash, isAsset).entries());
            
    //         var minPrice: Nat32 = 0;
    //         if(Nat.greater(assetOffers.size(), 0)) {
    //             let orderMin = func (x: (Nat32, T.SellOrder), y: (Nat32, T.SellOrder)) : ((Nat32, T.SellOrder)) { if(Nat32.less(x.1.price, y.1.price)) x else y };
    //             let bestOffer = Array.foldLeft<(Nat32, T.SellOrder), (Nat32, T.SellOrder)>(assetOffers, assetOffers[0], orderMin);
    //             minPrice := bestOffer.1.price;
    //         };

    //         let assetStats = {
    //             offerNftId= offerNftId;
    //             count= Nat32.fromNat(assetOffers.size());
    //             price= minPrice;
    //         };
    //         _res := List.push(assetStats, _res);
    //     };
    //     List.toArray(_res)
    // };

    // public query({caller}) func getCreatorAssetsStats(assetIds: [Text]) : async [(T.CreatorSalesStats)] {
    //     var _res = Buffer.Buffer<T.CreatorSalesStats>(assetIds.size());
    //     for(offerNftId in Iter.fromArray(assetIds)) {
    //         let isMyAssetSales = func (x : Nat32, y: T.SalesContract) : ?T.SalesContract {
    //             if (
    //                 (y.sellOrder.offerNftId == offerNftId)
    //                 and
    //                 List.some<Principal>(List.fromArray(y.parties), func (z: Principal): Bool = Principal.equal(caller, z))
    //                 ) ?y else null
    //             };
    //         let _assetSales = Iter.toArray(HashMap.mapFilter<Nat32, T.SalesContract, T.SalesContract>(_salesContracts, Nat32.equal, L.hash, isMyAssetSales).entries());

    //         var mintInSales: Nat32 = 0;
    //         if(Nat.greater(_assetSales.size(), 0)) {
    //             let sumFunc = func (x: (Nat32, Nat32), y: (Nat32, T.SalesContract)) : ((Nat32, Nat32)) { (x.0+y.1.purchasePrice, if(Principal.equal(y.1.seller, caller) == false) x.1+y.1.purchasePrice else x.1) };
    //             let initial: (Nat32, Nat32) = (_assetSales[0].1.purchasePrice, if(Principal.equal(_assetSales[0].1.seller, caller) == false) _assetSales[0].1.purchasePrice else 0);
    //             let test = Array.foldLeft<(Nat32, T.SalesContract), (Nat32, Nat32)>(_assetSales, initial, sumFunc);
    //             let (mySales, myCommissions) = test;
    //         _res.add({offerNftId=offerNftId; sales=mySales; commissions=myCommissions});
    //         };
    //     };
    //     Buffer.toArray(_res)
    // };

    public query({caller}) func resetDatastore() : async () {
        let _emptyArray2 : [(Text, T.SalesContractInput)] = [];
        _buyOrders := HashMap.fromIter(_emptyArray2.vals(), 0,Text.equal, Text.hash);
        let _emptyArray3 : [(Nat32, T.SalesContract)] = [];
        _salesContracts := HashMap.fromIter(_emptyArray3.vals(), 0, Nat32.equal, L.hash);
    };
};