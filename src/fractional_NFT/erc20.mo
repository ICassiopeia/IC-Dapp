/*
ERC20 - note the following:
-No notifications (can be added)
-All tokenids are ignored
-You can use the canister address as the token id
-Memo is ignored
-No transferFrom (as transfer includes a from field)
*/
import Cycles "mo:base/ExperimentalCycles";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";

//Get the path right
import AID "../toniq-ext/motoko/util/AccountIdentifier";
import ExtCore "../toniq-ext/motoko/ext/Core";
import ExtCommon "../toniq-ext/motoko/ext/Common";
import ExtAllowance "../toniq-ext/motoko/ext/Allowance";

import T "../libs/types";

actor class erc20_token(init_name: Text, init_symbol: Text, init_decimals: Nat8, init_supply: ExtCore.Balance, init_owner: Principal) {
  
  // Types  
  private let EXTENSIONS : [ExtCore.Extension] = ["@ext/common", "@ext/allowance"];

  // Cycles
  private var capacity = 1000000000000000000;
  private var balance = Cycles.balance();
  
  //State work
  private stable var _balancesState : [(ExtCore.AccountIdentifier, ExtCore.Balance)] = [];
  private var _balances : HashMap.HashMap<ExtCore.AccountIdentifier, ExtCore.Balance> = HashMap.fromIter(_balancesState.vals(), 0, AID.equal, AID.hash);
  private var _allowances = HashMap.HashMap<ExtCore.AccountIdentifier, HashMap.HashMap<Principal, ExtCore.Balance>>(1, AID.equal, AID.hash);
  
  //State functions
  system func preupgrade() {
    _balancesState := Iter.toArray(_balances.entries());
    //Allowances are not stable, they are lost during upgrades...
  };
  system func postupgrade() {
    _balancesState := [];
  };
  
  //Initial state - could set via class setter
  private stable let METADATA : ExtCommon.Metadata = #fungible({
    name = init_name;
    symbol = init_symbol;
    decimals = init_decimals;
    metadata = null;
  }); 
  private stable var _supply : ExtCore.Balance  = init_supply;
  
  _balances.put(AID.fromPrincipal(init_owner, null), _supply);

  public shared(msg) func transfer(request: ExtCore.TransferRequest) : async ExtCore.TransferResponse {
    let owner = ExtCore.User.toAID(request.from);
    let spender = AID.fromPrincipal(msg.caller, request.subaccount);
    let receiver = ExtCore.User.toAID(request.to);
    
    switch (_balances.get(owner)) {
      case (?owner_balance) {
        if (owner_balance >= request.amount) {
          if (AID.equal(owner, spender) == false) {
            //Operator is not owner, so we need to validate here
            switch (_allowances.get(owner)) {
              case (?owner_allowances) {
                switch (owner_allowances.get(msg.caller)) {
                  case (?spender_allowance) {
                    if (spender_allowance < request.amount) {
                      return #err(#Other("Spender allowance exhausted"));
                    } else {
                      var spender_allowance_new : ExtCore.Balance = spender_allowance - request.amount;
                      owner_allowances.put(msg.caller, spender_allowance_new);
                      _allowances.put(owner, owner_allowances);
                    };
                  };
                  case (_) {
                    return #err(#Unauthorized(spender));
                  };
                };
              };
              case (_) {
                return #err(#Unauthorized(spender));
              };
            };
          };
          
          var owner_balance_new : ExtCore.Balance = owner_balance - request.amount;
          _balances.put(owner, owner_balance_new);
          var receiver_balance_new = switch (_balances.get(receiver)) {
            case (?receiver_balance) {
                receiver_balance + request.amount;
            };
            case (_) {
                request.amount;
            };
          };
          _balances.put(receiver, receiver_balance_new);
          return #ok(request.amount);
        } else {
          return #err(#InsufficientBalance);
        };
      };
      case (_) {
        return #err(#InsufficientBalance);
      };
    };
  };
  
  public shared(msg) func approve(request: ExtAllowance.ApproveRequest) : async () {
    let owner = AID.fromPrincipal(msg.caller, request.subaccount);
    switch (_allowances.get(owner)) {
      case (?owner_allowances) {
        owner_allowances.put(request.spender, request.allowance);
        _allowances.put(owner, owner_allowances);
      };
      case (_) {
        var temp = HashMap.HashMap<Principal, ExtCore.Balance>(1, Principal.equal, Principal.hash);
        temp.put(request.spender, request.allowance);
        _allowances.put(owner, temp);
      };
    };
  };

  public query func extensions() : async [ExtCore.Extension] {
    EXTENSIONS;
  };
  
  public query func balanceUser(request : ExtCore.BalanceRequest) : async ExtCore.BalanceResponse {
    let aid = ExtCore.User.toAID(request.user);
    switch (_balances.get(aid)) {
      case (?balance) {
        return #ok(balance);
      };
      case (_) {
        return #ok(0);
      };
    }
  };

  public query func supply(token : ExtCore.TokenIdentifier) : async Result.Result<ExtCore.Balance, ExtCore.CommonError> {
    #ok(_supply);
  };
  
  public query func metadata(token : ExtCore.TokenIdentifier) : async Result.Result<ExtCommon.Metadata, ExtCore.CommonError> {
    #ok(METADATA);
  };

  //
  // Extention to Standard for F-NFT: START
  //
  public func getBalances() : async ([(ExtCore.AccountIdentifier, ExtCore.Balance)]) {
    Iter.toArray(_balances.entries())
  };

  public func getNftStats() : async (T.NftStats) {
    return {
      supply= _supply;
      left= _supply-_balances.size();
    };
  };

  public func isUserOwner(user: ExtCore.AccountIdentifier) : async (Bool) {
    switch (_balances.get(user)) {
      case (?balance) {
        if(Nat.greaterOrEqual(balance, 1)) {return true;}
        else {return false;}
      };
      case (_) {
        return false;
      };
    }
  };

  
  //
  // Extention to Standard for F-NFT: END
  //

  //Internal cycle management - good general case
  // public func acceptCycles() : async () {
  //   let available = Cycles.available();
  //   let accepted = Cycles.accept(available);
  //   assert (accepted == available);
  // };
  // public query func availableCycles() : async Nat {
  //   return Cycles.balance();
  // };

  // Returns the cycles received up to the capacity allowed
  public func wallet_receive() : async { accepted: Nat64 } {
      let amount = Cycles.available();
      let limit : Nat = capacity - balance;
      let accepted = 
          if (amount <= limit) amount
          else limit;
      let deposit = Cycles.accept(accepted);
      assert (deposit == accepted);
      balance += accepted;
      { accepted = Nat64.fromNat(accepted) };
  };
}