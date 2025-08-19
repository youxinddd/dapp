// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "OpenZeppelin/openzeppelin-contracts@4.9.3/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MyProxy is ERC1967Proxy {
    constructor(address _logic, bytes memory _data) ERC1967Proxy(_logic, _data) {}
}