// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {GovToken} from "../src/GovToken.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {Box} from "../src/Box.sol";

contract MyGovernorTest is Test {
    MyGovernor private myGovernor;
    GovToken private govToken;
    TimeLock private timeLock;
    Box private box;

    uint256 public constant MIN_DELAY = 3600; // 1 hour - after a vote passes, you have 1 hour before you can enact
    uint256 public constant QUORUM_PERCENTAGE = 4; // Need 4% of voters to pass
    uint256 public constant VOTING_PERIOD = 50400; // This is how long voting lasts
    uint256 public constant VOTING_DELAY = 1; // How many blocks till a proposal vote becomes active

    address[] proposers;
    address[] executors;

    address[] targets;
    uint256[] values;
    bytes[] calldatas;

    address public constant VOTER = address(1);
    uint256 public constant INITIAL_SUPPLY = 100e18;

    function setUp() external {
        vm.startPrank(VOTER);

        // Deploying the token contract
        govToken = new GovToken();

        // let's mint some tokens for the VOTER
        govToken.mint(VOTER, INITIAL_SUPPLY);

        // delegate the voting power to the voter
        // eventhough voter has tokens, he should be authorized to vote
        govToken.delegate(VOTER);

        // Deploying the timelock contract
        timeLock = new TimeLock(MIN_DELAY, proposers, executors);
        // right now since proposers and executors are blank
        // anyone can propose and execute

        // Deploying the governor contract
        myGovernor = new MyGovernor(govToken, timeLock);

        // assigning Roles
        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 cancellerRole = timeLock.CANCELLER_ROLE();

        timeLock.grantRole(proposerRole, address(myGovernor));
        // proposer role is now switched to governor contract
        // only governor can propose proposals

        timeLock.grantRole(executorRole, address(0));
        // by setting to address(0) anyone can be executor

        timeLock.revokeRole(cancellerRole, VOTER);
        // Voter will no longer be the admin

        vm.stopPrank();

        // Deploying the box contract
        box = new Box();
        box.transferOwnership(address(timeLock));
        // box will be owned by the timeLock
        // only the proposal has passed and min_delay has passed
        // timeLock will execute the proposal
        // timeLock is owned by the Governor
    }

    function test_CantUpdateBox_WithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function test_Governance_UpdatesBox() public {
        uint256 valueToStore = 123;

        targets.push(address(box)); // which contract to target

        values.push(0); // not sending any ETH

        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);
        calldatas.push(encodedFunctionCall); // which function to target in the targetted contract

        string memory description = "Store 1 in Box";

        // 1. Propose to the DAO
        uint256 proposalId = myGovernor.propose(targets, values, calldatas, description);
        // proposal has been created but it will be in pending state right now
        // after Voting_delay it will become active

        // View the state of the proposal
        console.log("Proposal State: ", uint256(myGovernor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        // 2. Vote
        uint8 voteWay = 1;
        // 0 = Against, 1 = For, 2 = Abstain for this example

        string memory reason = "cuz I like the proposal";

        vm.startPrank(VOTER);
        myGovernor.castVoteWithReason(proposalId, voteWay, reason);
        vm.stopPrank();

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // by using warp we are simulating that voting period is over

        // View the state of the proposal
        console.log("Proposal State: ", uint256(myGovernor.state(proposalId)));
        // proposal state will be active

        // 3. Queue the TX
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        myGovernor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // after voting is done
        // we have to wait till min_delay

        // 4. Execute
        myGovernor.execute(targets, values, calldatas, descriptionHash);

        assertEq(box.readNumber(), valueToStore, "readNumberFromBox");
    }
}
