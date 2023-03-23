// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BanklessToken is ERC20, Ownable {
    constructor() ERC20("Bankless", "Bank") {
        // Mint initial supply of rewards tokens to the owner (optional)
        _mint(msg.sender, 1000000 * (18 ** decimals()));
    }

    // Function to mint new tokens (accessible only by the owner)
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}
