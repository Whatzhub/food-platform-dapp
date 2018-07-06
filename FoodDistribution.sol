pragma solidity ^0.4.19;

import "./SafeMath.sol";
import "./Ownable.sol";

contract FoodDistribution is Ownable {
    
    using SafeMath for uint;
    using SafeMath for uint256;
    using SafeMath32 for uint32;
    using SafeMath16 for uint16;
    
    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);
    event FoodTaker(uint32 indexed hkId, uint16 foodTokenBal);
    event FoodVendor(string name, uint8 vendorType, uint16 foodTokenBal, uint32 indexed brNo);
    event FoodToken(uint foodTakerBal, uint foodVendorBal, uint32 indexed brNo);
    
    modifier onlyVendor(uint32 _brNo) {
        require (msg.sender == brNoToFoodVendor[_brNo]);
        _;
    }
    
    struct FoodTakers {
        string pin; // a keccak256 hash of the 4-digit secret pin
        uint16 foodTokenBal; // food balance integer, max 65,535 food units given
        uint32 hkId; // first 7 numeric digits of HKID, e.g. 7238912
        uint32 readyTime; // cooldown period before using another food token
    }
    
    struct FoodVendors {
        string name; // name of vendor
        uint8 vendorType; // 1 = supermarkets, 2 = food suppliers, 3 = restaurants
        uint16 foodTokenBal; // food balance integer, max 65,535 food units earned
        uint32 brNo; // 8 numberic digits of business registration number, e.g. 30182245
    }
    
    // This creates an array for all food takers & food vendors
    FoodTakers[] public foodtakers;
    FoodVendors[] public foodvendors;
    
    // mapping keys to address values on the blockchain
    mapping (uint => address) public brNoToFoodVendor; // e.g. 30182245 => eth address
    mapping (uint => uint) public brNoToFoodVendors; // e.g. 30182245 => index 19 of foodvendors[]
    mapping (uint => uint) public hkIdToFoodTakers; // e.g. 7238912 => index 22 of foodtakers[]
    
    uint256 balance;
    uint256 foodTokenVal = 100 finney; // or 0.1 ether
    uint256 cooldownTime = 12 hours;
    
    // intialising of values for contract creation
    constructor () public payable{
        balance = msg.value; // init Contract with Eth amount
    }
    
    // allow owner to top up eth to contract
    function deposit () onlyOwner public payable {
        balance = balance.add(msg.value);
    }
    
    // allow owner to view contract
    function balanceOf () onlyOwner external view returns (uint) {
        return balance;
    }
    
    function balanceOfFoodTaker(uint32 _hkId) public view returns (uint16 foodTokenBal, uint32 hkId, uint32 readyTime) {
        FoodTakers memory data = foodtakers[hkIdToFoodTakers[_hkId]];
        return (data.foodTokenBal, data.hkId, data.readyTime);
    }
    
    function balanceOfFoodVendor(uint32 _brNo) onlyVendor(_brNo) public view returns (uint16 foodTokenBal, uint32 brNo, string name, uint8 vendorType ) {
        FoodVendors memory data = foodvendors[brNoToFoodVendors[_brNo]];
        return (data.foodTokenBal, data.brNo, data.name, data.vendorType);
    }
    
    function _checkDuplicateFoodTaker(uint32 _hkId) internal view returns (bool) {
    for (uint i = 0; i < foodtakers.length; i++) {
      if (keccak256(foodtakers[i].hkId) == keccak256(_hkId)) {
        return false;
      }
    }
    return true;
  }
  
  function _checkDuplicateFoodVendor(uint32 _brNo) internal view returns (bool) {
    for (uint i = 0; i < foodvendors.length; i++) {
      if (keccak256(foodvendors[i].brNo) == keccak256(_brNo)) {
        return false;
      }
    }
    return true;
  }
    
    // register first time food takers onto blockchain
    // @dev wallet address not required
    function _registerFoodTaker(uint32 _hkId, string _pin) internal {
        uint index = foodtakers.push(FoodTakers(_pin, 10, _hkId, 0)) - 1;
        hkIdToFoodTakers[_hkId] = index;
        emit FoodTaker(_hkId, 10);
    }
    
    // register first time food vendors onto blockchain
    // @dev require mapping their public eth address
    // @dev public permissionless registrar for vendors
    function _registerFoodVendor(string _name, uint8 _type, uint32 _brNo) internal {
        uint index = foodvendors.push(FoodVendors(_name, _type, 0, _brNo)) - 1;
        brNoToFoodVendor[_brNo] = msg.sender;
        brNoToFoodVendors[_brNo] = index;
        emit FoodVendor(_name, _type, 0, _brNo);
    }
    
    function registerFoodTaker(uint32 _hkId, string _pin) public {
        // prevent double registration
        require(_checkDuplicateFoodTaker(_hkId));
        _registerFoodTaker(_hkId, _pin);
    }
    
    function registerFoodVendor(string _name, uint8 _type, uint32 _brNo) public {
        // prevent double registration
        require(_checkDuplicateFoodVendor(_brNo));
        _registerFoodVendor(_name, _type, _brNo);
    }
    
    function _triggerCooldown(FoodTakers storage _foodtaker) internal {
        _foodtaker.readyTime = uint32(now + cooldownTime);
    }

    function _isReady(FoodTakers storage _foodtaker) internal view returns (bool) {
        return (_foodtaker.readyTime <= now);
    }
    
    function useFoodToken(uint32 _hkId, string _pin, uint32 _brNo) public onlyVendor(_brNo) {
        // Verification for food taker
        require(keccak256(_pin) == keccak256(foodtakers[hkIdToFoodTakers[_hkId]].pin));
        require(_isReady(foodtakers[hkIdToFoodTakers[_hkId]]));
        FoodTakers storage foodTaker = foodtakers[hkIdToFoodTakers[_hkId]];
        FoodVendors storage foodVendor = foodvendors[brNoToFoodVendors[_brNo]];
        foodTaker.foodTokenBal = foodTaker.foodTokenBal.sub(1);
        foodVendor.foodTokenBal = foodVendor.foodTokenBal.add(1);
        _triggerCooldown(foodTaker);
        emit FoodToken(foodTaker.foodTokenBal, foodVendor.foodTokenBal, _brNo);
        
        // _useFoodToken(foodTaker, foodVendor, _brNo);
    }
    
    function withdraw(uint32 _brNo, uint _amount) public onlyVendor(_brNo) returns(bool) {
        FoodVendors storage foodVendor = foodvendors[brNoToFoodVendors[_brNo]];
        require(_amount <= balance);
        require(_amount <= foodVendor.foodTokenBal);
        // deduct food vendor token & contract eth balance
        foodVendor.foodTokenBal = foodVendor.foodTokenBal.sub(uint16(_amount));
        balance = balance.sub(uint256(_amount * foodTokenVal));
        // transfer food tokens (eth) to target vendor
        msg.sender.transfer(_amount * foodTokenVal);
        emit Transfer(msg.sender, owner, _amount * foodTokenVal);
        return true;
    }
    
}