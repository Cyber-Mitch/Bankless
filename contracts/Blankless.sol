// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Bankless is ReentrancyGuard {
    
    mapping (address => bytes32) public uniqueChars;
    mapping (bytes32 => address) public charToAddress;
    mapping (address => uint) public balances;
    mapping (address => uint) public stakedBalances;
    address payable owner;
    
    uint public annualRewardRate = 1000; // Annual reward rate in basis points (10%)
    uint public compoundingPeriods = 104; // Compounding periods (approximately every 3.5 days)

    uint public minimumStakingDuration = 30 days; // Users must stake for at least one month before withdrawing their balances

    mapping(address => uint) public lastRewardUpdate;
    mapping(address => uint) public stakingStartTime;

    IERC20 public banklessToken;

    constructor(IERC20 _banklessToken) {
        owner = payable(msg.sender);
        banklessToken = _banklessToken;
    }
    modifier isDepositor() {
        require(uniqueChars[msg.sender] != bytes32(0), "Only depositors can perform this action");
        _;
    }

    function deposit() public payable returns (bytes32) {
        bytes32 _uniqueChars = generateUniqueChars();
        require(charToAddress[_uniqueChars] == address(0), "Unique characters already used");
        
        uint depositAmount = msg.value;
        uint depositFee = depositAmount / 5;
        uint depositAmountAfterFee = depositAmount - depositFee;
        
        balances[msg.sender] += depositAmountAfterFee;
        balances[owner] += depositFee;
        
        uniqueChars[msg.sender] = encryptUniqueCharacters(_uniqueChars);
        charToAddress[_uniqueChars] = msg.sender;
        
        return _uniqueChars;
    }
    
    function withdraw(bytes32 _uniqueChars, address payable _wallet, address _depositAddress, uint _amount) public nonReentrant{
        require(charToAddress[_uniqueChars] == _depositAddress, "Invalid unique characters or deposit address");
        require(_wallet != address(0), "Invalid wallet address");
        require(_wallet == msg.sender,"The connected wallet address should be the withdrawal address");
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
        bytes32 randBytes = bytes32(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, block.coinbase))));
        return randBytes;
    }
    
    function encryptUniqueCharacters(bytes32 _uniqueChars) internal pure returns (bytes32) {
        bytes32 hashedChars = keccak256(abi.encodePacked(_uniqueChars));
        return hashedChars;
    }
    
    function withdrawFees() public nonReentrant{
        require(msg.sender == owner, "Only owner can withdraw fees");
        uint feeAmount = balances[owner];
        require(feeAmount > 0, "No fees to withdraw");
        balances[owner] = 0;
        (bool success, ) = owner.call{value: feeAmount}("");
        require(success, "Failed to send fees");
    }

    // Function to stake tokens
    function stake(uint _amount) public isDepositor {
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        require(_amount > 0, "Invalid amount");

        stakingStartTime[msg.sender] = block.timestamp;
        lastRewardUpdate[msg.sender] = block.timestamp;

        balances[msg.sender] -= _amount;
        stakedBalances[msg.sender] += _amount;
    }

    // Function to update user balance
    function checkBalance() public isDepositor {
        require(block.timestamp >= lastRewardUpdate[msg.sender] + 1 weeks, "User balance can be Updated and Checked every week");
        updateRewards(msg.sender);
    }

    // Function to unstake tokens and withdraw rewards
    function unstakeAndWithdrawRewards() public isDepositor {
        require(block.timestamp >= stakingStartTime[msg.sender] + minimumStakingDuration, "Minimum staking duration not met");
        updateRewards(msg.sender);
        // uint stakedAmount = stakedBalances[msg.sender];
        // stakedBalances[msg.sender] = 0;
        // balances[msg.sender] += stakedAmount;
        uint stakedAmount = stakedBalances[msg.sender];
        uint rewardsAmount = balances[msg.sender];

        stakedBalances[msg.sender] = 0;
        balances[msg.sender] = 0;

        // Transfer Ether back to the user
        payable(msg.sender).transfer(stakedAmount);

        // Transfer Bankless Token rewards to the user
        require(banklessToken.transfer(msg.sender, rewardsAmount), "Failed to transfer rewards");
    }

    // Function to update rewards
    function updateRewards(address _user) internal {
        if (block.timestamp >= lastRewardUpdate[_user] + 1 weeks) {
            uint rewards = calculateRewards(_user);
            stakedBalances[_user] += rewards;
            balances[_user] += rewards;
            
            lastRewardUpdate[_user] = block.timestamp;
        }
    }

    // Function to calculate rewards
    function calculateRewards(address _user) internal view returns (uint) {
        uint stakedBalance = stakedBalances[_user];
        uint stakingDuration = block.timestamp - lastRewardUpdate[_user];

        uint effectiveAnnualRate = (annualRewardRate * stakingDuration) / (365 days);
        uint periods = (compoundingPeriods * stakingDuration) / (365 days);

        uint stakedAmountWithRewards = stakedBalance * (1 + (effectiveAnnualRate / compoundingPeriods)) ** periods;
        uint rewards = stakedAmountWithRewards - stakedBalance;

        return rewards;
    }
}