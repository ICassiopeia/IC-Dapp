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

import FNFT "canister:fractional_NFT";
import T "./types";
import L "../libs/libs";

actor swap_contracts {

    //State work
    private stable var _offersState : [(Nat32, T.SellOrder)] = [];
    private var _offers : HashMap.HashMap<Nat32, T.SellOrder> = HashMap.fromIter(_offersState.vals(), 0, Nat32.equal, L.hash);
	
    private stable var _buyOrdersState : [(Text, T.SalesContractInput)] = [];
    private var _buyOrders : HashMap.HashMap<Text, T.SalesContractInput> = HashMap.fromIter(_buyOrdersState.vals(), 0,Text.equal, Text.hash);
	
    private stable var _salesContractsState : [(Nat32, T.SalesContract)] = [];
    private var _salesContracts : HashMap.HashMap<Nat32, T.SalesContract> = HashMap.fromIter(_salesContractsState.vals(), 0, Nat32.equal, L.hash);
 
    private stable var _totalCount : Nat32  = 0;
    private stable var _totalSuccessCount : Nat32  = 0;
    private stable var _nextSalesId : Nat32  = 0;

    //State functions
    system func preupgrade() {
        _offersState := Iter.toArray(_offers.entries());
        _buyOrdersState := Iter.toArray(_buyOrders.entries());
        _salesContractsState := Iter.toArray(_salesContracts.entries());
    };

    system func postupgrade() {
        _offersState := [];
        _buyOrdersState := [];
        _salesContractsState := [];
    };

    //
    // Sell functions
    //
    public shared({caller}) func sellOrder(userId: Principal, orderData: T.SellOrderInput) : async Result.Result<Nat32, Text> {
        if(orderData.orderType == #gift) {
            assert(Text.notEqual(orderData.secret, ""));
            assert(Nat32.equal(orderData.price, 0));
        } else {
            assert(Text.equal(orderData.secret, ""));
            assert(Nat32.greaterOrEqual(orderData.price, 100));
        };

        switch (await FNFT.getNFTOwner(orderData.nftToken)) {
            case (?nftOwner) {
                assert(Principal.equal(nftOwner, userId));
                switch (await FNFT.metadata(Nat32.toText(orderData.nftToken))) {
                    case (#ok(nft)) {
                        let order: T.SellOrder = {
                            seller= userId;
                            nftToken= orderData.nftToken;
                            assetId= ""; //nft.properties.assetId;
                            collectionId= 1; //nft.properties.collectionId;
                            fromDate= Time.now();
                            toDate= orderData.toDate;
                            price= orderData.price;
                            orderType= orderData.orderType;
                            secret= orderData.secret;
                            createdAt= Time.now();
                            updatedAt= Time.now();
                        };
                        _offers.put(order.nftToken, order);
                        return #ok(order.nftToken);
                    };
                    case (_) {
                        return #err("NFT not found - ERR002");
                    };
                };
            };
            case (_) {
                return #err("NFT not found - ERR001");
            };
        };
    };

    public shared({caller}) func batchSellOrder(userId: Principal, orderData: [T.SellOrderInput]) : async () {
        for(order in Iter.fromArray(orderData)) {
            let res = await sellOrder(userId, order);
        };
    };

    public query func getSellOrderByCollectionId(collectionId: Nat32) : async [(Nat32, T.SellOrder)] {
        let isInCollection = func (x : Nat32, y: T.SellOrder) : ?T.SellOrder { if ((y.collectionId == collectionId) and (y.orderType == #marketplace)) ?y else null };
        Iter.toArray(HashMap.mapFilter<Nat32, T.SellOrder, T.SellOrder>(_offers, Nat32.equal, L.hash, isInCollection).entries())
    };

    public query func getSellOrderByUserId(userId: Principal) : async [(T.SellOrderType)] {
        let isInCollection = func (x : Nat32, y: T.SellOrder) : ?T.SellOrder { if ((y.seller == userId) and (y.orderType == #marketplace)) ?y else null };
        let orders = Iter.toArray(HashMap.mapFilter<Nat32, T.SellOrder, T.SellOrder>(_offers, Nat32.equal, L.hash, isInCollection).entries());
        Array.map<(Nat32, T.SellOrder), T.SellOrderType>(orders, func(x : Nat32, y: T.SellOrder) { {id=x; order=y ;} } )
    };

    public query func getSellOrderByAssetId(assetId: Text) : async [(T.SellOrderType)] {
        let isAsset = func (x : Nat32, y: T.SellOrder) : ?T.SellOrder { if ((y.assetId == assetId) and (y.orderType == #marketplace)) ?y else null };
        let orders = Iter.toArray(HashMap.mapFilter<Nat32, T.SellOrder, T.SellOrder>(_offers, Nat32.equal, L.hash, isAsset).entries());
        Array.map<(Nat32, T.SellOrder), T.SellOrderType>(orders, func(x : Nat32, y: T.SellOrder) { {id=x; order=y ;} } )
    };

    public query({caller}) func getSellOrders() : async [(Nat32, T.SellOrder)] {
        Iter.toArray(_offers.entries())
    };

    //
    // Buy functions
    //

    public query({caller}) func getBuyOrder() : async [(Text, T.SalesContractInput)] {
        // TODO: secure
        Iter.toArray(_buyOrders.entries())
    };

    public shared({caller}) func buyOrder(transactionId: Text, buyer: Principal, order: T.BuyOrderInput) : async Result.Result<Text, Text> {
        // Buy orders to reservations
        let orders = await getSellOrderByAssetId(order.assetId);
        assert(orders.size() > 0);
        let orderMin = func (x: T.SellOrderType, y: T.SellOrderType) : (T.SellOrderType) { if(Nat32.less(x.order.price, y.order.price)) x else y };
        let bestOffer = Array.foldLeft<T.SellOrderType, T.SellOrderType>(orders, orders[0], orderMin);
        if(Nat32.lessOrEqual(bestOffer.order.price, order.purchasePrice)) {
            _nextSalesId := _nextSalesId + 1;
            let finalOrder: T.BuyOrder = {
                buyer= buyer;
                assetId= order.assetId;
                purchasePrice= order.purchasePrice;
                createdAt= Time.now();
                updatedAt= Time.now();
            };
            let buyOrderRecord : T.SalesContractInput = {
                offerId= _nextSalesId;
                buyOrder= finalOrder;
                sellRef= bestOffer;
                orderType= #marketplace;
            };
            _buyOrders.put(transactionId, buyOrderRecord);
            #ok(transactionId)
        } else {
            #err("No offer matches buy order [ERR0010]");
        };
    };

    public shared({caller}) func executeBuyOrder(transactionId: Text) : async Result.Result<(Nat32, Principal), Text> {
        switch (_buyOrders.get(transactionId)) {
            case (?res) {
                let result = await _executeSalesOrder(res.offerId, res.buyOrder, res.sellRef, res.orderType);
                #ok((res.offerId, res.sellRef.order.seller))
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

    public query func getSalesOrderByAssetId(assetId: Text) : async [(T.SalesContractType)] {
        let isAsset = func (x : Nat32, y: T.SalesContract) : ?T.SalesContract { if (y.sellOrder.assetId == assetId) ?y else null };
        let contracts = Iter.toArray(HashMap.mapFilter<Nat32, T.SalesContract, T.SalesContract>(_salesContracts, Nat32.equal, L.hash, isAsset).entries());
        Array.map<(Nat32, T.SalesContract), T.SalesContractType>(contracts, func(x : Nat32, y: T.SalesContract) { {id=x; contract=y ;} } )
    };

    public query({caller}) func getSalesOrderByUserId() : async [(T.SalesContractType)] {
        let isAssetIds = func (x : Nat32, y: T.SalesContract) : ?T.SalesContract {if(List.some<Principal>(List.fromArray(y.parties), func (z: Principal): Bool = Principal.equal(caller, z))) ?y else null };
        let contracts = Iter.toArray(HashMap.mapFilter<Nat32, T.SalesContract, T.SalesContract>(_salesContracts, Nat32.equal, L.hash, isAssetIds).entries());
        Array.map<(Nat32, T.SalesContract), T.SalesContractType>(contracts, func(x : Nat32, y: T.SalesContract) { {id=x; contract=y ;} } )
    };

    private func _executeSalesOrder(offerId: Nat32, buyOrder: T.BuyOrder, sellRef: T.SellOrderType, orderType: T.SalesTypes) : async T.SalesContract {
        let executionDate = Time.now();
        // var _transactions: [T.Transaction] = [];
        var _transactions = List.nil<T.Transaction>();
        var _parties: [Principal] = [];
        // if(orderType == #marketplace) {
            // base transaction
            let baseTransaction: T.Transaction = {
                from= buyOrder.buyer;
                to= sellRef.order.seller;
                value= sellRef.order.price;
                transactionType= #base;
                executionDate= executionDate;
            };
            _transactions := List.push(baseTransaction, _transactions);
            let isFirstSale = (await getSalesOrderByNftId(sellRef.id)).size() == 0;

            _parties := [buyOrder.buyer, sellRef.order.seller];
        // };

        let finalOffer: T.SalesContract = {
            buyer= buyOrder.buyer;
            seller= sellRef.order.seller;
            nftId= sellRef.id;
            purchasePrice= sellRef.order.price;
            status= #approved;
            executionDate= executionDate;
            executionType= orderType;
            transactions=List.toArray(_transactions);
            parties=_parties;
            buyOrder=buyOrder;
            sellOrder=sellRef.order;
        };

        _offers.delete(sellRef.id);
        _salesContracts.put(offerId, finalOffer);
        await FNFT.transferFrom(finalOffer.seller, finalOffer.buyer, finalOffer.nftId);
        finalOffer
    };

    //
    // Gift functions
    //

    public shared({caller}) func redeemGift(user: Principal, code: Text) : async Result.Result<Text, Text> {
        let isTargetedGift = func (x : Nat32, y: T.SellOrder) : ?T.SellOrder { if (y.secret == code) ?y else null };
        let giftResult = Iter.toArray(HashMap.mapFilter<Nat32, T.SellOrder, T.SellOrder>(_offers, Nat32.equal, L.hash, isTargetedGift).entries());

        if(giftResult.size() == 1) {
            _nextSalesId := _nextSalesId + 1;
            let (giftId, giftDetails) = giftResult[0];
            let buyOrder: T.BuyOrder = {
                buyer= user;
                assetId= giftDetails.assetId;
                purchasePrice= giftDetails.price;
                createdAt= Time.now();
                updatedAt= Time.now();
            };
            let result = await _executeSalesOrder(_nextSalesId, buyOrder, {id=giftId; order=giftDetails}, #gift);
            return #ok(giftDetails.assetId);
        } else {
            return #err("Gift link is broken - ERR005");
        };
        
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


    public query func getTopSales() : async [(Text, T.TopSalesStats)] {
        let inLast14Days = func (x : Nat32, y: T.SalesContract) : ?T.SalesContract { if ((y.executionDate >= Time.now()-1209600000000000) and (y.executionType == #marketplace)) ?y else null };
        let lastSalesContracts = HashMap.mapFilter<Nat32, T.SalesContract, T.SalesContract>(_salesContracts, Nat32.equal, L.hash, inLast14Days);
        // let extractPrice = func (x : Nat32, y: T.SalesContract) : (Text, Nat32) { (y.buyOrder.assetId, y.purchasePrice) };

        var _aggregatedSales = HashMap.HashMap<Text, T.TopSalesStats>(0, Text.equal, Text.hash);
        for(sale in lastSalesContracts.entries()) {
            let (_, contract) = sale;
            var lastWeek: Nat32 = 0;
            var twoWeeksAgo: Nat32 = 0;
            var count: Nat32 = 1;

            if(Int.greaterOrEqual(contract.executionDate, Time.now()-604800000000000)) lastWeek := contract.purchasePrice
            else twoWeeksAgo := contract.purchasePrice;

            switch (_aggregatedSales.get(contract.buyOrder.assetId)) {
                case (?res) {
                    lastWeek := lastWeek + res.lastWeek;
                    twoWeeksAgo := twoWeeksAgo + res.twoWeeksAgo;
                    count := count + res.count;
                };
                case (_) {};
            };
            _aggregatedSales.put((contract.buyOrder.assetId, {
                lastWeek=lastWeek;
                twoWeeksAgo=twoWeeksAgo;
                count=count;
            }));
        };
        Iter.toArray(_aggregatedSales.entries())
    };

    public query func getAssetStats(assetId: Text) : async (T.SalesStats) {
        let isAsset = func (x : Nat32, y: T.SellOrder) : ?T.SellOrder { if ((y.assetId == assetId) and (y.orderType == #marketplace)) ?y else null };
        let assetOffers = Iter.toArray(HashMap.mapFilter<Nat32, T.SellOrder, T.SellOrder>(_offers, Nat32.equal, L.hash, isAsset).entries());

        var minPrice: Nat32 = 0;
        if(Nat.greater(assetOffers.size(), 0)) {
            let orderMin = func (x: (Nat32, T.SellOrder), y: (Nat32, T.SellOrder)) : ((Nat32, T.SellOrder)) { if(Nat32.less(x.1.price, y.1.price)) x else y };
            let bestOffer = Array.foldLeft<(Nat32, T.SellOrder), (Nat32, T.SellOrder)>(assetOffers, assetOffers[0], orderMin);
            minPrice := bestOffer.1.price;
        };

        {
            assetId= assetId;
            count= Nat32.fromNat(assetOffers.size());
            price= minPrice;
        };
    };

    public query func getManyAssetStats(assetIds: [Text]) : async [(T.SalesStats)] {
        var _res = List.nil<T.SalesStats>();
        for(assetId in Iter.fromArray(assetIds)) {
            let isAsset = func (x : Nat32, y: T.SellOrder) : ?T.SellOrder { if ((y.assetId == assetId) and (y.orderType == #marketplace)) ?y else null };
            let assetOffers = Iter.toArray(HashMap.mapFilter<Nat32, T.SellOrder, T.SellOrder>(_offers, Nat32.equal, L.hash, isAsset).entries());
            
            var minPrice: Nat32 = 0;
            if(Nat.greater(assetOffers.size(), 0)) {
                let orderMin = func (x: (Nat32, T.SellOrder), y: (Nat32, T.SellOrder)) : ((Nat32, T.SellOrder)) { if(Nat32.less(x.1.price, y.1.price)) x else y };
                let bestOffer = Array.foldLeft<(Nat32, T.SellOrder), (Nat32, T.SellOrder)>(assetOffers, assetOffers[0], orderMin);
                minPrice := bestOffer.1.price;
            };

            let assetStats = {
                assetId= assetId;
                count= Nat32.fromNat(assetOffers.size());
                price= minPrice;
            };
            _res := List.push(assetStats, _res);
        };
        List.toArray(_res)
    };

    public query({caller}) func getCreatorAssetsStats(assetIds: [Text]) : async [(T.CreatorSalesStats)] {
        var _res = Buffer.Buffer<T.CreatorSalesStats>(assetIds.size());
        for(assetId in Iter.fromArray(assetIds)) {
            let isMyAssetSales = func (x : Nat32, y: T.SalesContract) : ?T.SalesContract {
                if (
                    (y.sellOrder.assetId == assetId)
                    and
                    List.some<Principal>(List.fromArray(y.parties), func (z: Principal): Bool = Principal.equal(caller, z))
                    ) ?y else null
                };
            let _assetSales = Iter.toArray(HashMap.mapFilter<Nat32, T.SalesContract, T.SalesContract>(_salesContracts, Nat32.equal, L.hash, isMyAssetSales).entries());

            var mintInSales: Nat32 = 0;
            if(Nat.greater(_assetSales.size(), 0)) {
                let sumFunc = func (x: (Nat32, Nat32), y: (Nat32, T.SalesContract)) : ((Nat32, Nat32)) { (x.0+y.1.purchasePrice, if(Principal.equal(y.1.seller, caller) == false) x.1+y.1.purchasePrice else x.1) };
                let initial: (Nat32, Nat32) = (_assetSales[0].1.purchasePrice, if(Principal.equal(_assetSales[0].1.seller, caller) == false) _assetSales[0].1.purchasePrice else 0);
                let test = Array.foldLeft<(Nat32, T.SalesContract), (Nat32, Nat32)>(_assetSales, initial, sumFunc);
                let (mySales, myCommissions) = test;
            _res.add({assetId=assetId; sales=mySales; commissions=myCommissions});
            };
        };
        Buffer.toArray(_res)
    };

    public query({caller}) func resetDatastore() : async () {
        let _emptyArray1 : [(Nat32, T.SellOrder)] = [];
        _offers := HashMap.fromIter(_emptyArray1.vals(), 0, Nat32.equal, L.hash);
        let _emptyArray2 : [(Text, T.SalesContractInput)] = [];
        _buyOrders := HashMap.fromIter(_emptyArray2.vals(), 0,Text.equal, Text.hash);
        let _emptyArray3 : [(Nat32, T.SalesContract)] = [];
        _salesContracts := HashMap.fromIter(_emptyArray3.vals(), 0, Nat32.equal, L.hash);
    };
};