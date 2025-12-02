// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GenericVotingContractImpl.sol";

contract GenericVoting_JSONRunner is Test {

    GenericVotingContractImpl voting;

    function setUp() public {
        voting = new GenericVotingContractImpl();
    }

    // ------------------------------
    // Simple Yes/No Voting
    // ------------------------------
    function test_SimpleVoting() public {
        _run("./test/data/Simple_YesNo_Voting.json");
    }

    // ------------------------------
    // Quadratic Voting (single candidate)
    // ------------------------------
    function test_QuadraticVoting() public {
        _run("./test/data/Quadratic_Voting.json");
    }

    // ------------------------------
    // Token-Based Approval Voting (single candidate)
    // ------------------------------
    function test_TokenBasedVoting() public {
        _run("./test/data/Token_Based_Voting.json");
    }

    // ------------------------------
    // Ranked Multi-Candidate Voting
    // ------------------------------
    function test_RankedVoting() public {
        _run("./test/data/Ranked_MultiCandidate_Voting.json");
    }

    // ------------------------------------------------------
    // Ortak runner
    // ------------------------------------------------------
    function _run(string memory path) internal {
        console2.log("\n Running:", path);
        string memory json = vm.readFile(path);

        string memory desc = vm.parseJsonString(json, ".description");
        uint8 votingTypeId = uint8(vm.parseJsonUint(json, ".votingTypeId"));
        uint256 startTime = vm.parseJsonUint(json, ".startTime");
        uint256 endTime = vm.parseJsonUint(json, ".endTime");
        uint256 quorum = vm.parseJsonUint(json, ".quorum");
        string memory costType = vm.parseJsonString(json, ".voteCostType");
        uint256 lower = vm.parseJsonUint(json, ".lowerLimit");
        uint256 upper = vm.parseJsonUint(json, ".upperLimit");
        bool repetition = vm.parseJsonBool(json, ".repetitionAllowed");
        uint256 candidateCount = vm.parseJsonUint(json, ".candidateCount");
        uint256 sessionCount = vm.parseJsonUint(json, ".sessionCount");

        // -----------------------------------------
        // tokenAddress opsiyonel, yoksa address(0)
        // -----------------------------------------
        address tokenAddr = address(0);
        if (vm.keyExists(json, ".tokenAddress")) {
            tokenAddr = vm.parseJsonAddress(json, ".tokenAddress");
        }

        // -----------------------------------------
        // Proposal create
        // -----------------------------------------
	//string[] storage tags;
        //tags.push( "tag1");
        //tags.push( "tag1");
	//tags[0] =  "tag1";
	//tags[1] = "tag2";
        uint256 id = voting.createProposal(
            desc,
            1,
            "DefaultCommunity",
            address(this),
            1,
            GenericVotingContractImpl.CommunityRestriction.All,
            GenericVotingContractImpl.VotingStructure({
                votingStructureId: 1,
                name: "Default",
                voteCostType: GenericVotingContractImpl.VoteCostType.Free,
                tokenAddress: tokenAddr,
                lowerLimit: lower,
                upperLimit: upper,
                onlyYes: false,
                onlyOnce: !repetition
            }),
            0,
            quorum,
            startTime,
            endTime,
            address(0)//,
 	    //tags
           
        );
        //ÖNEMLİ: JSON'daki sessionCount'u kontrata yaz
        voting.setProposalTotalSessions(id, sessionCount);

        vm.warp(startTime + 10);

        // -----------------------------------------
        // Ranked / Multi-Session
        // -----------------------------------------
        if (votingTypeId == 4) {
            for (uint256 s = 0; s < sessionCount; s++) {
                string memory pathVotes = string.concat(".sessions[", vm.toString(s), "].votes");
                bytes memory raw = vm.parseJson(json, pathVotes);
                RankedVoteInput[] memory votes = abi.decode(raw, (RankedVoteInput[]));

                for (uint256 j = 0; j < votes.length; j++) {
                    GenericVotingContractImpl.Vote memory v;
                    v.voteId = 0;
                    v.votingStructureId = 1;
                    v.proposalId = id;
                    v.yesno = true;
                    v.numericValue = votes[j].value;
                    v.voterAddress = votes[j].voter;
                    v.voterChainId = 1;
                    v.chainCurrentVotingWeight = 1;
                    v.chainCurrentProposalVotingWeight = 1;
                    v.memberCurrentVotingWeight = 1;
                    v.memberCurrentProposalVotingWeight = 1;
                    v.optionId = votes[j].optionId;

                    vm.prank(votes[j].voter);
                    voting.vote(v, 1);
                }

                if (s < sessionCount - 1) {
                    voting.nextSession(id);
                }
            }

        } else {
            // ---------------------------------------------------
            // SIMPLE / QUADRATIC / TOKEN (single session)
            // ---------------------------------------------------
            bytes memory raw = vm.parseJson(json, ".sessions[0].votes");

            if (candidateCount == 1) {
                // Single option → no optionId in JSON
                SingleOptionVoteInput[] memory votes =
                    abi.decode(raw, (SingleOptionVoteInput[]));

                for (uint256 j = 0; j < votes.length; j++) {
                    _castSingle(id, votes[j].voter, votes[j].value);
                }
            } else {
                MultiOptionVoteInput[] memory votes =
                    abi.decode(raw, (MultiOptionVoteInput[]));

                for (uint256 j = 0; j < votes.length; j++) {
                    _castMulti(id, votes[j].voter, votes[j].optionId, votes[j].value);
                }
            }
        }

        vm.warp(endTime + 1);

        (uint cur, uint total) = voting.getProposalSessions(id);
        console2.log("Completed:", desc);
        console2.log("  Session:", cur, "/", total);
    }

    // ---------------------
    // Vote helpers
    // ---------------------
    function _castSingle(uint256 id, address voter, uint256 value) internal {
        GenericVotingContractImpl.Vote memory v;
        v.voteId = 0;
        v.votingStructureId = 1;
        v.proposalId = id;
        v.yesno = true;
        v.numericValue = value;
        v.voterAddress = voter;
        v.voterChainId = 1;
        v.chainCurrentVotingWeight = 1;
        v.chainCurrentProposalVotingWeight = 1;
        v.memberCurrentVotingWeight = 1;
        v.memberCurrentProposalVotingWeight = 1;
        v.optionId = 1;

        vm.prank(voter);
        voting.vote(v, 1);
    }

    function _castMulti(uint256 id, address voter, uint256 optionId, uint256 value) internal {
        GenericVotingContractImpl.Vote memory v;
        v.voteId = 0;
        v.votingStructureId = 1;
        v.proposalId = id;
        v.yesno = true;
        v.numericValue = value;
        v.voterAddress = voter;
        v.voterChainId = 1;
        v.chainCurrentVotingWeight = 1;
        v.chainCurrentProposalVotingWeight = 1;
        v.memberCurrentVotingWeight = 1;
        v.memberCurrentProposalVotingWeight = 1;
        v.optionId = optionId;

        vm.prank(voter);
        voting.vote(v, 1);
    }

    // JSON structs
    struct SingleOptionVoteInput {
        address voter;
        uint256 value;
    }

    struct MultiOptionVoteInput {
        address voter;
        uint256 optionId;
        uint256 value;
    }

    struct RankedVoteInput {
        address voter;
        uint256 optionId;
        uint256 value;
    }
}
