// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GenericVoting.sol";

contract GenericVotingTest is Test {
    GenericVoting voting;

    function setUp() public {
        voting = new GenericVoting();
    }

    function testCreateProposal() public {
        uint256 start = block.timestamp;
        uint256 end = block.timestamp + 1 days;
        uint256 id = voting.createProposal("Test Proposal", GenericVoting.VotingType.Simple, start, end);
        assertEq(id, 1, "Proposal ID should be 1");
    }

    function testVote() public {
        uint256 start = block.timestamp;
        uint256 end = block.timestamp + 1 days;
        uint256 id = voting.createProposal("Proposal", GenericVoting.VotingType.Simple, start, end);

        voting.vote(id, 5);
        // burada emit edilen event'i yakalayabiliriz ama şimdilik basic test
        assertEq(id, 1);
    }
}

