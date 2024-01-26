// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {
    // minDelay -> How long you have to wait before executing
    // proposers -> List of addresses that can propose
    // executors -> List of addresees that can execute
    // admin -> Admin
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors)
        TimelockController(minDelay, proposers, executors, msg.sender)
    {}
}
