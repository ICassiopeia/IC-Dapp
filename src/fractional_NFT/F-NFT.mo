/*
Cronics
*/
import Cycles "mo:base/ExperimentalCycles";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import AID "../toniq-ext/motoko/util/AccountIdentifier";
import ExtCore "../toniq-ext/motoko/ext/Core";
import ExtCommon "../toniq-ext/motoko/ext/Common";
import ExtAllowance "../toniq-ext/motoko/ext/Allowance";
import ExtNonFungible "../toniq-ext/motoko/ext/NonFungible";

import Option "mo:base/Option";
import Blob "mo:base/Blob";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Time "mo:base/Time";
import List "mo:base/List";
import Buffer "mo:base/Buffer";
import Nat "mo:base/Nat";

import T "../libs/types";
import L "../libs/libs";

import ERC20 "erc20";

actor FractionalNFT {
  
  type DataTokenType = ERC20.erc20_token;
  
  //HTTP
  type HeaderField = (Text, Text);
  type HttpResponse = {
    status_code: Nat16;
    headers: [HeaderField];
    body: Blob;
  };
  type HttpRequest = {
    method : Text;
    url : Text;
    headers : [HeaderField];
    body : Blob;
  };
  
  
  private let EXTENSIONS : [ExtCore.Extension] = ["@ext/common", "@ext/allowance", "@ext/nonfungible"];
  
  //State work
  private stable var _registryState : [(ExtCore.TokenIndex, ExtCore.AccountIdentifier)] = [];
  private var _registry : HashMap.HashMap<ExtCore.TokenIndex, ExtCore.AccountIdentifier> = HashMap.fromIter(_registryState.vals(), 0, ExtCore.TokenIndex.equal, ExtCore.TokenIndex.hash);
  
  private stable var _datasetRelState : [(Nat32, [ExtCore.TokenIndex])] = [];
  private var _datasetRel : HashMap.HashMap<Nat32, [ExtCore.TokenIndex]> = HashMap.fromIter(_datasetRelState.vals(), 0, Nat32.equal, L.hash);
  
  private stable var _buyersState : [(ExtCore.AccountIdentifier, [ExtCore.TokenIndex])] = [];
  private var _buyers : HashMap.HashMap<ExtCore.AccountIdentifier, [ExtCore.TokenIndex]> = HashMap.fromIter(_buyersState.vals(), 0, AID.equal, AID.hash);
	
  private stable var _allowancesState : [(ExtCore.TokenIndex, Principal)] = [];
  private var _allowances : HashMap.HashMap<ExtCore.TokenIndex, Principal> = HashMap.fromIter(_allowancesState.vals(), 0, ExtCore.TokenIndex.equal, ExtCore.TokenIndex.hash);
	
	private stable var _tokenMetadataState : [(ExtCore.TokenIndex, T.Metadata)] = [];
  private var _tokenMetadata : HashMap.HashMap<ExtCore.TokenIndex, T.Metadata> = HashMap.fromIter(_tokenMetadataState.vals(), 0, ExtCore.TokenIndex.equal, ExtCore.TokenIndex.hash);
  
	private stable var _dataTokenState : [(ExtCore.TokenIndex, DataTokenType)] = [];
  private var _dataTokens : HashMap.HashMap<ExtCore.TokenIndex, DataTokenType> = HashMap.fromIter(_dataTokenState.vals(), 0, ExtCore.TokenIndex.equal, ExtCore.TokenIndex.hash);
  
  private stable var _supply : ExtCore.Balance  = 0;
  // private stable var _minter : Principal  = Principal.fromText("2lhsj-gqaaa-aaaai-acouq-cai");
  private stable var _minter : Principal  = Principal.fromText("ryjl3-tyaaa-aaaaa-aaaba-cai");
  private stable var _gifter : Principal  = _minter;
  private stable var _nextTokenId : ExtCore.TokenIndex  = 0;
  private stable var _nextToSell : ExtCore.TokenIndex  = 0;

  //State functions
  system func preupgrade() {
    _registryState := Iter.toArray(_registry.entries());
    _datasetRelState := Iter.toArray(_datasetRel.entries());
    _buyersState := Iter.toArray(_buyers.entries());
    _allowancesState := Iter.toArray(_allowances.entries());
    _tokenMetadataState := Iter.toArray(_tokenMetadata.entries());
    _dataTokenState := Iter.toArray(_dataTokens.entries());
  };
  system func postupgrade() {
    _registryState := [];
    _datasetRelState := [];
    _buyersState := [];
    _allowancesState := [];
    _tokenMetadataState := [];
    _dataTokenState := [];
  };

  //
  // Toniq EXT - START
  //
  public shared(msg) func disribute(user : ExtCore.User) : async () {
		assert(Principal.equal(msg.caller, _minter));
		assert(_nextToSell < _nextTokenId);
    let bearer = ExtCore.User.toAID(user);
		_registry.put(_nextToSell, bearer);
    
    switch (_buyers.get(bearer)) {
      case (?nfts) {
        var _nfts: Buffer.Buffer<ExtCore.TokenIndex> = Buffer.fromArray<ExtCore.TokenIndex>(nfts);
        _nfts.add(_nextToSell);
        _buyers.put(bearer, Buffer.toArray(_nfts));
      };
      case (_) {
        _buyers.put(bearer, [_nextToSell]);
      };
    };
		_nextToSell := _nextToSell + 1;
	};
  
	public shared(msg) func setMinter(minter : Principal) : async () {
		assert(msg.caller == _minter);
		_minter := minter;
	};
	
  public shared(msg) func freeGift(bearer : ExtCore.AccountIdentifier) : async ?ExtCore.TokenIndex {
		assert(msg.caller == _gifter);
		assert(_nextToSell < _nextTokenId);
    if (_nextToSell < 5000) {
      let tokenid = _nextToSell + 1000;
      _registry.put(tokenid, bearer);
      switch (_buyers.get(bearer)) {
        case (?nfts) {
          var _nfts: Buffer.Buffer<ExtCore.TokenIndex> = Buffer.fromArray<ExtCore.TokenIndex>(nfts);
          _nfts.add(tokenid);
          _buyers.put(bearer, Buffer.toArray(_nfts));
        };
        case (_) {
          _buyers.put(bearer, [tokenid]);
        };
      };
      _nextToSell := _nextToSell + 1;
      return ?tokenid;
    } else {
      return null;
    }
	};
  
  public shared(msg) func transfer(request: ExtCore.TransferRequest) : async ExtCore.TransferResponse {
    if (request.amount != 1) {
			return #err(#Other("Must use amount of 1"));
		};
		// if (ExtCore.TokenIdentifier.isPrincipal(request.token, Principal.fromActor(this)) == false) {
		// 	return #err(#InvalidToken(request.token));
		// };
		let token = ExtCore.TokenIdentifier.getIndex(request.token);
    let owner = ExtCore.User.toAID(request.from);
    let spender = AID.fromPrincipal(msg.caller, request.subaccount);
    let receiver = ExtCore.User.toAID(request.to);
		
    switch (_registry.get(token)) {
      case (?token_owner) {
				if(AID.equal(owner, token_owner) == false) {
					return #err(#Unauthorized(owner));
				};
				if (AID.equal(owner, spender) == false) {
					switch (_allowances.get(token)) {
						case (?token_spender) {
							if(Principal.equal(msg.caller, token_spender) == false) {								
								return #err(#Unauthorized(spender));
							};
						};
						case (_) {
							return #err(#Unauthorized(spender));
						};
					};
				};
				_allowances.delete(token);
				_registry.put(token, receiver);
				return #ok(request.amount);
      };
      case (_) {
        return #err(#InvalidToken(request.token));
      };
    };
  };
  
  public shared(msg) func approve(request: ExtAllowance.ApproveRequest) : async () {
		// if (ExtCore.TokenIdentifier.isPrincipal(request.token, Principal.fromActor(this)) == false) {
		// 	return;
		// };
		let token = ExtCore.TokenIdentifier.getIndex(request.token);
    let owner = AID.fromPrincipal(msg.caller, request.subaccount);
		switch (_registry.get(token)) {
      case (?token_owner) {
				if(AID.equal(owner, token_owner) == false) {
					return;
				};
				_allowances.put(token, request.spender);
        return;
      };
      case (_) {
        return;
      };
    };
  };

  public query func getSold() : async ExtCore.TokenIndex {
    _nextToSell;
  };
  public query func getMinted() : async ExtCore.TokenIndex {
    _nextTokenId;
  };
  public query func getMinter() : async Principal {
    _minter;
  };
  
  public query func extensions() : async [ExtCore.Extension] {
    EXTENSIONS;
  };
  
  public query func balance(request : ExtCore.BalanceRequest) : async ExtCore.BalanceResponse {
		// if (ExtCore.TokenIdentifier.isPrincipal(request.token, Principal.fromActor(this)) == false) {
		// 	return #err(#InvalidToken(request.token));
		// };
		let token = ExtCore.TokenIdentifier.getIndex(request.token);
    let aid = ExtCore.User.toAID(request.user);
    switch (_registry.get(token)) {
      case (?token_owner) {
				if (AID.equal(aid, token_owner) == true) {
					return #ok(1);
				} else {					
					return #ok(0);
				};
      };
      case (_) {
        return #err(#InvalidToken(request.token));
      };
    };
  };
	
	public query func allowance(request : ExtAllowance.AllowanceRequest) : async Result.Result<ExtCore.Balance, ExtCore.CommonError> {
		// if (ExtCore.TokenIdentifier.isPrincipal(request.token, Principal.fromActor(this)) == false) {
		// 	return #err(#InvalidToken(request.token));
		// };
		let token = ExtCore.TokenIdentifier.getIndex(request.token);
		let owner = ExtCore.User.toAID(request.owner);
		switch (_registry.get(token)) {
      case (?token_owner) {
				if (AID.equal(owner, token_owner) == false) {					
					return #err(#Other("Invalid owner"));
				};
				switch (_allowances.get(token)) {
					case (?token_spender) {
						if (Principal.equal(request.spender, token_spender) == true) {
							return #ok(1);
						} else {					
							return #ok(0);
						};
					};
					case (_) {
						return #ok(0);
					};
				};
      };
      case (_) {
        return #err(#InvalidToken(request.token));
      };
    };
  };
  
	public query func index(token : ExtCore.TokenIdentifier) : async Result.Result<ExtCore.TokenIndex, ExtCore.CommonError> {
		// if (ExtCore.TokenIdentifier.isPrincipal(token, Principal.fromActor(this)) == false) {
		// 	return #err(#InvalidToken(token));
		// };
		#ok(ExtCore.TokenIdentifier.getIndex(token));
	};
  
	public query func bearer(token : ExtCore.TokenIdentifier) : async Result.Result<ExtCore.AccountIdentifier, ExtCore.CommonError> {
		// if (ExtCore.TokenIdentifier.isPrincipal(token, Principal.fromActor(this)) == false) {
		// 	return #err(#InvalidToken(token));
		// };
		let tokenind = ExtCore.TokenIdentifier.getIndex(token);
    switch (_registry.get(tokenind)) {
      case (?token_owner) {
				return #ok(token_owner);
      };
      case (_) {
        return #err(#InvalidToken(token));
      };
    };
	};

	public query func isOwner(caller: Principal, token : Nat32) : async (Bool) {
    switch (_registry.get(token)) {
      case (?token_owner) Principal.equal(caller,  Principal.fromText(token_owner));
      case (_) false;
    };
	};
  
	public query func supply(token : ExtCore.TokenIdentifier) : async Result.Result<ExtCore.Balance, ExtCore.CommonError> {
    #ok(_supply);
  };
  
  public query func getBuyers() : async [(ExtCore.AccountIdentifier, [ExtCore.TokenIndex])] {
    Iter.toArray(_buyers.entries());
  };
  public query func getRegistry() : async [(ExtCore.TokenIndex, ExtCore.AccountIdentifier)] {
    Iter.toArray(_registry.entries());
  };
  public query func getAllowances() : async [(ExtCore.TokenIndex, Principal)] {
    Iter.toArray(_allowances.entries());
  };
  public query func getTokens() : async [(ExtCore.TokenIndex, T.Metadata)] {
    Iter.toArray(_tokenMetadata.entries());
  };

  public query func metadata(token : ExtCore.TokenIdentifier) : async Result.Result<T.Metadata, ExtCore.CommonError> {
    // if (ExtCore.TokenIdentifier.isPrincipal(token, Principal.fromActor(this)) == false) {
		// 	return #err(#InvalidToken(token));
		// };
		let tokenind = ExtCore.TokenIdentifier.getIndex(token);
    switch (_tokenMetadata.get(tokenind)) {
      case (?token_metadata) {
				return #ok(token_metadata);
      };
      case (_) {
        return #err(#InvalidToken(token));
      };
    };
  };
  
  //Frontend
  public query func http_request(request : HttpRequest) : async HttpResponse {
    switch(getTokenData(getParam(request.url, "tokenid"))) {
      case (?svgdata) {
        return {
          status_code = 200;
          headers = [("content-type", "image/svg+xml")];
          // body = Blob.fromArray(svgdata);
          body = Blob.fromArray([]);
        }
      };
      case (_) {
        return {
          status_code = 200;
          headers = [("content-type", "text/plain")];
          body = Text.encodeUtf8 (
            "My current cycle balance:                 " # debug_show (Cycles.balance()) # "\n" #
            "Minted NFTs:                              " # debug_show (_nextTokenId) # "\n" #
            "Distributed NFTs:                         " # debug_show (_nextToSell) # "\n" #
            "Admin:                                    " # debug_show (_minter) # "\n"
          )
        }
      }      
    };
  };
  
  func getTokenData(tokenid : ?Text) : ?T.Metadata {
    switch (tokenid) {
      case (?token) {
        // if (ExtCore.TokenIdentifier.isPrincipal(token, Principal.fromActor(this)) == false) {
        //   return null;
        // };
        let tokenind = ExtCore.TokenIdentifier.getIndex(token);
				return _tokenMetadata.get(tokenind);
      };
      case (_) {
        return null;
      };
    };
  };
  
  func getParam(url : Text, param : Text) : ?Text {
    var _s : Text = url;
    Iter.iterate<Text>(Text.split(_s, #text("/")), func(x, _i) {
      _s := x;
    });
    Iter.iterate<Text>(Text.split(_s, #text("?")), func(x, _i) {
      if (_i == 1) _s := x;
    });
    var t : ?Text = null;
    var found : Bool = false;
    Iter.iterate<Text>(Text.split(_s, #text("&")), func(x, _i) {
      Iter.iterate<Text>(Text.split(x, #text("=")), func(y, _ii) {
        if (_ii == 0) {
          if (Text.equal(y, param)) found := true;
        } else if (found == true) t := ?y;
      });
    });
    return t;
  };
  
  //Internal cycle management - good general case
  public func acceptCycles() : async () {
    let available = Cycles.available();
    let accepted = Cycles.accept(available);
    assert (accepted == available);
  };
  public query func availableCycles() : async Nat {
    return Cycles.balance();
  };
  //
  // Toniq EXT - END
  //




  //
  // Fractional NFT
  //

  private func _updateAssetOfferList(dataAssetId : Nat32, token: ExtCore.TokenIndex, mode: T.UpdateMode) : () {
    switch(_datasetRel.get(dataAssetId)) {
      case (?_tokenList) {
        if(mode == #Add) {
          _datasetRel.put(dataAssetId, List.toArray(List.push(token, List.fromArray(_tokenList))));
        } else {
          _datasetRel.put(dataAssetId, Array.filter<ExtCore.TokenIndex>(_tokenList, func(t) { return (ExtCore.TokenIndex.equal(t, token) == false) } ));
        };
      };
      case (_) {
        if(mode == #Add) {
          _datasetRel.put(dataAssetId, Array.make<ExtCore.TokenIndex>(token));
        };
      };
    };
  };

  // CREATE
  public shared(msg) func mintOfferNft(
    token: ExtCore.TokenIndex,
    request : T.MintRequest,
    name: Text,
    symbol: Text,
    initialSupply: Nat) : async ExtCore.TokenIndex {

    let receiver = ExtCore.User.toAID(request.to);
		let md : T.Metadata = {
      name= name;
      description= request.metadata.description;
      dataAssetId= request.metadata.dataAssetId;
      isEnabled= true;
      price= request.metadata.price;
      supply= request.metadata.supply;
      timeLimitSeconds= request.metadata.timeLimitSeconds;
      dimensionRestrictList= request.metadata.dimensionRestrictList;
      isGdrpEnabled= request.metadata.isGdrpEnabled;
      createdAt= Time.now();
      updatedAt= Time.now();
    };
    // Mint ERC721
		_registry.put(token, receiver);
		_tokenMetadata.put(token, md);
    _updateAssetOfferList(request.metadata.dataAssetId, token, #Add);
    // Mint ERC20
    Cycles.add(250_000_000_000);
    let erc20 = await ERC20.erc20_token(name, symbol, 0, initialSupply, msg.caller);
    let amountAccepted = await erc20.wallet_receive();
    _dataTokens.put(token, erc20);
    // Misc.
		_supply := _supply + 1;
		_nextTokenId := _nextTokenId + 1;
    token;
	};

  // READ
  public query func getOfferNfts(dataAssetId: Nat32) : async ?[ExtCore.TokenIndex] {
    _datasetRel.get(dataAssetId)
  };

  public query func getManyOfferNftMetdata(tokens: [ExtCore.TokenIndex]) : async [T.OfferNftInfo] {
    var res = Buffer.Buffer<T.OfferNftInfo>(tokens.size());
    for(token in Iter.fromArray(tokens)) {
      switch(_tokenMetadata.get(token)) {
        case (?_metadata) res.add({
          id=token;
          owner=Option.unwrap(_registry.get(token));
          metadata=_metadata;
        });
        case (_) {};
      };
    };
    Buffer.toArray(res)
  };

  public func getOfferNftACL(token: ExtCore.TokenIndex) : async [(ExtCore.AccountIdentifier, ExtCore.Balance)] {
    switch(_dataTokens.get(token)) {
      case (?_erc20) (await _erc20.getBalances());
      case (_) [];
    };
  };

  public func getOfferNftStats(token: ExtCore.TokenIndex) : async (T.NftStats) {
    switch(_dataTokens.get(token)) {
      case (?_erc20) (await _erc20.getNftStats());
      case (_) T.nullNftStats;
    };
  };

  public func getManyOfferNftStats(tokens: [ExtCore.TokenIndex]) : async [(ExtCore.TokenIndex, T.NftStats)] {
    var res = Buffer.Buffer<(ExtCore.TokenIndex, T.NftStats)>(tokens.size());
    for(token in Iter.fromArray(tokens)) {
      let subResult: T.NftStats = switch(_dataTokens.get(token)) {
        case (?_erc20) (await _erc20.getNftStats());
        case (_) T.nullNftStats;
      };
      res.add((token, subResult))
    };
    Buffer.toArray(res)
  };

  public shared({caller}) func isUserAnNftOwner(token: ExtCore.TokenIndex) : async Bool {
    switch(_dataTokens.get(token)) {
      case (?_erc20) (await _erc20.isUserOwner(AID.fromPrincipal(caller, null)));
      case (_) false;
    };
  };

  public shared({caller}) func getUserDatasetAccess(dataAssetId: Nat32, targerUser: ?Principal) : async ([T.MetadataSmall]) {
    let user: Principal = switch(targerUser) {
      case(?principal) principal;
      case(_) caller;
    };
    switch(_datasetRel.get(dataAssetId)) {
      case (?_nfts) {
        var arr = Buffer.Buffer<T.MetadataSmall>(_nfts.size());
        for(nft in Iter.fromArray(_nfts)) {
          switch(_dataTokens.get(nft)) {
            case (?_erc20) {
                if(await _erc20.isUserOwner(AID.fromPrincipal(user, null)))
                  switch(_tokenMetadata.get(nft)) {
                    case (?_meta) {
                      let newMeta: T.MetadataSmall = {
                        name= _meta.name;
                        dataAssetId= _meta.dataAssetId;
                        isEnabled= _meta.isEnabled;
                        price= _meta.price;
                        supply= _meta.supply;
                        timeLimitSeconds= _meta.timeLimitSeconds;
                        dimensionRestrictList= _meta.dimensionRestrictList;
                        isGdrpEnabled= _meta.isGdrpEnabled;
                      };
                      arr.add(newMeta);
                      };
                    case (_) {};
                  };
              };
            case (_) {};
          };
        };
        Buffer.toArray(arr);
      };
      case (_) [];
    };
  };

  public shared({caller}) func getUserFNfts(targerUser: ?Principal) : async ([T.Metadata]) {
    let user: Principal = switch(targerUser) {
      case(?principal) principal;
      case(_) caller;
    };
    let _nfts = _tokenMetadata.entries();
    var arr = Buffer.Buffer<T.Metadata>(10);
    for((nftId, metadata) in _nfts) {
      switch(_dataTokens.get(nftId)) {
        case (?_erc20) {
            if(await _erc20.isUserOwner(AID.fromPrincipal(user, null)))
              arr.add(metadata);
          };
        case (_) {};
      };
    };
    Buffer.toArray(arr)
  };

  public func isBuyable(token: ExtCore.TokenIndex) : async Bool {
    let check1 = switch(_tokenMetadata.get(token)) {
      case (?_config) _config.isEnabled==true;
      case (_) false;
    };
    let check2 = switch(_dataTokens.get(token)) {
      case (?_erc20) {
        let stats = await _erc20.getNftStats();
        Nat.greaterOrEqual(stats.left, 1)
      };
      case (_) false;
    };
    check1 and check2
  };

  public func getFNftStats(token: ExtCore.TokenIndex) : async T.NftStats {
    switch(_dataTokens.get(token)) {
      case (?_erc20) await _erc20.getNftStats();
      case (_) {return {supply= 9999; left= 9999}};
    }
  };

  public func getSellingPrice(token: ExtCore.TokenIndex) : async Nat32 {
    switch(_tokenMetadata.get(token)) {
      case (?_config) _config.price;
      case (_) 0;
    };
  };

  public query func findCollectionByAssetId(token: Nat32) : async () {
  };

  // DELETE
  public query func deleteNFT(token: Nat32) : async Bool {
    switch(_tokenMetadata.get(token)) {
      case (?_meta) {
        let newMeta = {
          name= _meta.name;
          description= _meta.description;
          dataAssetId= _meta.dataAssetId;
          isEnabled= false;
          price= _meta.price;
          supply= _meta.supply;
          timeLimitSeconds= _meta.timeLimitSeconds;
          dimensionRestrictList= _meta.dimensionRestrictList;
          isGdrpEnabled= _meta.isGdrpEnabled;
          createdAt= _meta.createdAt;
          updatedAt= Time.now();
        };
        _tokenMetadata.put(token, newMeta);
        _registry.delete(token);
        _updateAssetOfferList(_meta.dataAssetId, token, #Remove);
        _dataTokens.delete(token);
        true
      };
      case (_) false;
    }
  };

  // TRANSFER
  public shared({caller}) func transferFrom(from : ExtCore.AccountIdentifier, to : ExtCore.AccountIdentifier, token : Nat32) : async ?ExtCore.TransferResponse {
    switch(_dataTokens.get(token)) {
      case (?_erc20) {
        let request: ExtCore.TransferRequest = {
          from=  #address(from);
          to= #address(to);
          token= "";
          amount= 1;
          memo= Blob.fromArray([]);
          notify= false;
          subaccount= null;
        };
        ?(await _erc20.transfer(request));
      };
      case (_) null;
    }
  };
}