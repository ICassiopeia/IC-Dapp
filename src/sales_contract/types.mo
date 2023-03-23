
import Principal "mo:base/Principal";
import Nat32 "mo:base/Nat32";
import Hash "mo:base/Hash";

module {

    public type SellOrder = {
        seller: Principal;
        nftToken:Nat32;
        assetId: Text;
        collectionId:Nat32;
        fromDate: Int;
        toDate: Int;
        price: Nat32;
        orderType: SalesTypes;
        secret: Text;
        createdAt: Int;
        updatedAt: Int;
    };

    public type SellOrderInput = {
        nftToken: Nat32;
        toDate: Int;
        price: Nat32;
        orderType: SalesTypes;
        secret: Text;
    };

    public type SellOrderType = {
        id: Nat32;
        order: SellOrder;
    };

    public type BuyOrder = {
        buyer: Principal;
        assetId: Text;
        purchasePrice: Nat32;
        createdAt: Int;
        updatedAt: Int;
    };

    public type BuyOrderInput = {
        assetId: Text;
        purchasePrice: Nat32;
    };

    public type SalesStats = {
        assetId: Text;
        count: Nat32;
        price: Nat32;
    };

    public type SalesTypes = {
        #marketplace;
        #gift;
    };

    public type SalesContractStatus = {
        #pending;
        #blocked;
        #rejected;
        #approved;
    };

    public type SalesContract = {
        buyer: Principal;
        seller: Principal;
        nftId:Nat32;
        purchasePrice: Nat32;
        status: SalesContractStatus;
        executionDate: Int;
        executionType: SalesTypes;
        transactions: [Transaction];
        parties: [Principal];
        buyOrder: BuyOrder;
        sellOrder: SellOrder;
    };

    public type SalesContractType = {
        id: Nat32;
        contract: SalesContract;
    };

    public type Transaction = {
        from: Principal;
        to: Principal;
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
        sellRef: SellOrderType;
        orderType: SalesTypes;
    };

    public type CreatorSalesStats = {
        assetId: Text;
        sales: Nat32;
        commissions: Nat32;
    };

}