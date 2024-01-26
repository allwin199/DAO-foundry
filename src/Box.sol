// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// DAO will own this BOX
contract Box is Ownable {
    uint256 private s_number;

    event NumberChanged(uint256 number);

    constructor() Ownable(msg.sender) {}
    // Whoever deploys this contract will be the initial owner.
    // we can transfer ownership to the DAO contract.

    function store(uint256 newNumber) external onlyOwner {
        s_number = newNumber;
        emit NumberChanged(newNumber);
    }

    function readNumber() external view returns (uint256) {
        return s_number;
    }
}
