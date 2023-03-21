// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Bankless {
    
    mapping (address => bytes32) public uniqueChars;
    mapping (bytes32 => address) public charToAddress;
    mapping (address => uint) public balances;
    address payable owner;
    
    constructor() {
        owner = payable(msg.sender);
    }
    
    function deposit() public payable returns (bytes32) {
        bytes32 _uniqueChars = generateUniqueChars();
        require(charToAddress[_uniqueChars] == address(0), "Unique characters already used");
        
        uint depositAmount = msg.value;
        uint depositFee = depositAmount / 10;
        uint depositAmountAfterFee = depositAmount - depositFee;
        
        balances[msg.sender] += depositAmountAfterFee;
        balances[owner] += depositFee;
        
        uniqueChars[msg.sender] = encryptUniqueCharacters(_uniqueChars);
        charToAddress[_uniqueChars] = msg.sender;
        
        return _uniqueChars;
    }
    
    function withdraw(bytes32 _uniqueChars, address payable _wallet, address _depositAddress, uint _amount) public {
        require(charToAddress[_uniqueChars] == _depositAddress, "Invalid unique characters or deposit address");
        require(_wallet != address(0), "Invalid wallet address");
        require(balances[_depositAddress] >= _amount, "Insufficient balance");
        require(_amount > 0, "Invalid amount");
        require(_depositAddress != msg.sender, "Withdrawal address must be different from deposit address");
        
        balances[_depositAddress] -= _amount;
        
        (bool success, ) = _wallet.call{value: _amount}("");
        require(success, "Failed to send funds");
        if(balances[_depositAddress] == 0) {
             charToAddress[_uniqueChars] = address(0);
        }
       
    }

    function generateUniqueChars() internal view returns (bytes32) {
        bytes32 randBytes = bytes32(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, block.coinbase))));
        return randBytes;
    }
    
    function encryptUniqueCharacters(bytes32 _uniqueChars) internal pure returns (bytes32) {
        bytes32 hashedChars = keccak256(abi.encodePacked(_uniqueChars));
        return hashedChars;
    }
    
    function withdrawFees() public {
        require(msg.sender == owner, "Only owner can withdraw fees");
        uint feeAmount = balances[owner];
        require(feeAmount > 0, "No fees to withdraw");
        balances[owner] = 0;
        (bool success, ) = owner.call{value: feeAmount}("");
        require(success, "Failed to send fees");
    }
}
