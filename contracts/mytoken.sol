// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "OpenZeppelin/openzeppelin-contracts@4.9.3/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("TAOTAO", "TT") {
        _mint(msg.sender, initialSupply * (10 ** decimals()));
    }
}