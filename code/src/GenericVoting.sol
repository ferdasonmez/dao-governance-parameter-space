// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract GenericVotingContractImpl {
    // ───────────────────────────────────────── Enums
    enum VoteCostType { Free, OneTokenPerVote, SameAsVoteAmount, Quadratic }
    enum CommunityRestriction {
        OnlyProposingCommunity,
        OnlyProposingAndChildren,
        OnlyChildren,
        NotProposingCommunity,
        All
    }

    // ───────────────────────────────────────── Structs
    struct VoteGroup {
        uint[] proposalIds;
        string voteGroupName;
    }

    struct VotingStructure {
        uint votingStructureId;
        string name;
        VoteCostType voteCostType;
        address tokenAddress;
        uint256 lowerLimit;
        uint256 upperLimit;
        bool onlyYes;   // sadece olumlu/approval yönü mü?
        bool onlyOnce;  // session bazında tekrar yasak mı?
    }

    struct Vote {
        uint voteId;
        uint votingStructureId;
        uint proposalId;
        bool yesno;
        uint numericValue;
        address voterAddress;
        uint voterChainId;
        uint chainCurrentVotingWeight;
        uint chainCurrentProposalVotingWeight;
        uint memberCurrentVotingWeight;
        uint memberCurrentProposalVotingWeight;
        uint optionId; // YENİ: vote group içindeki aday/seçenek index’i
    }

    struct Proposal {
        uint256 id;
        string description;

        address proposingMemberAddress;
        uint proposingMemberChainId;
        uint proposingCommunityId;
        string proposingCommunityName;

        CommunityRestriction communityRestriction;

        // key = keccak256(voterAddress, voterChainId, proposalId, session)
        mapping(bytes32 => uint) voted;
        mapping(bytes32 => Vote) votes;

        // toplu sayaclar (proposal genelinde)
        uint256 numberOfVotes;
        uint256 numberOfYesVotes;
        uint256 numberOfNoVotes;
        uint256 sumOfYesVotes;
        uint256 sumOfNoVotes;

        bool executed;
        bool passed;
        uint quorum;
        uint256 startTime;
        uint256 endTime;

        uint256 votingStructureId;

        uint256 proposalBudget;
        address proposalImplementationAddress;

        // session & group
        uint256 currentSession; // aktif oturum
        uint256 totalSessions;  // toplam oturum (yoksa 1)
        uint256 voteGroupId;    // bağlı olduğu grup (opsiyonel)

        string[] tags;
    }

    struct ProposalBasicData {
        uint256 proposalId;
        string description;
        address proposingMemberAddress;
        uint proposingMemberChainId;
        uint proposingCommunityId;
        string proposingCommunityName;
        uint proposalCommunityRestriction;
        uint256 startTime;
        uint256 endTime;
        uint256 votingStructureId;
        string[] tags;
    }

    struct AccountChainPair {
        address account;
        uint chainId;
        string[] tags;
    }

    struct TransferData {
        address sender;
        address receiver;
        uint256 amount;
        string currencyType;
        bytes memo;
    }

    struct ContractFunctionCallData {
        address targetContractAddress;
        string targetcontractName;
        string targetfunctionName;
        bytes parameters;
    }

    // ───────────────────────────────────────── Storage
    uint256 private _proposalSeq;
    uint256 private _voteSeq;
    uint256 private _groupSeq;

    mapping(uint256 => Proposal) private _proposals;            // id -> Proposal
    mapping(uint256 => VotingStructure) private _votingStructs; // id -> VotingStructure
    mapping(uint256 => VoteGroup) private _voteGroups;          // id -> VoteGroup

    // YENİ: proposalId => session => optionId => sum(numericValue)
    mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256))) public optionVotes;

    // ───────────────────────────────────────── Events
    event ProposalCreated(
        uint256 indexed proposalId,
        string description,
        address indexed proposingMemberAddress,
        uint proposingMemberChainId,
        uint proposingCommunityId,
        string proposingCommunityName,
        uint256 proposalBudget,
        uint256 numberOfVotes,
        bool executed,
        bool passed,
        uint quorum,
        uint256 startTime,
        uint256 endTime,
        uint256 votingType,
        address proposalImplementationAddress,
        string[] tags
    );

    // ───────────────────────────────────────── Helpers
    function _newProposalId() internal returns (uint256) {
        _proposalSeq += 1;
        return _proposalSeq;
    }

    function _newVoteId() internal returns (uint256) {
        _voteSeq += 1;
        return _voteSeq;
    }

    function _sessionKey(address voter, uint chainId, uint proposalId, uint session)
        internal pure returns (bytes32)
    {
        return keccak256(abi.encodePacked(voter, chainId, proposalId, session));
    }

    // ───────────────────────────────────────── VotingStructure Management
    function upsertVotingStructure(VotingStructure memory vs) public {
        require(vs.votingStructureId != 0, "invalid vs id");
        _votingStructs[vs.votingStructureId] = vs;
    }

    // ───────────────────────────────────────── VoteGroup Management
    function createVoteGroup(string memory name, uint[] memory proposalIds) public returns (uint groupId) {
        _groupSeq += 1;
        groupId = _groupSeq;
        VoteGroup storage g = _voteGroups[groupId];
        g.voteGroupName = name;
        g.proposalIds = proposalIds;
    }

    function attachProposalToGroup(uint proposalId, uint groupId) public {
        Proposal storage p = _proposals[proposalId];
        p.voteGroupId = groupId;
        VoteGroup storage g = _voteGroups[groupId];
        g.proposalIds.push(proposalId);
    }

    // ───────────────────────────────────────── Create Proposal
    function createProposal(
        string memory _description,
        uint _communityId,
        string memory _communityName,
        address _proposingMemberAddress,
        uint _proposingMemberChainId,
        CommunityRestriction _communityRestriction,
        VotingStructure memory _votingStructure,
        uint256 _proposalBudget,
        uint _quorum,
        uint256 _startTime,
        uint256 _endTime,
        address _proposalImplementationAddress,
        string[] memory _tags
    ) public returns (uint256 proposalId) {
        if (_votingStructure.votingStructureId != 0) {
            _votingStructs[_votingStructure.votingStructureId] = _votingStructure;
        }

        proposalId = _newProposalId();
        Proposal storage proposal = _proposals[proposalId];

        proposal.id = proposalId;
        proposal.description = _description;
        proposal.proposingMemberAddress = _proposingMemberAddress;
        proposal.proposingMemberChainId = _proposingMemberChainId;
        proposal.proposingCommunityId = _communityId;
        proposal.proposingCommunityName = _communityName;
        proposal.communityRestriction = _communityRestriction;

        proposal.proposalBudget = _proposalBudget;
        proposal.startTime = _startTime;
        proposal.endTime = _endTime;
        proposal.votingStructureId = _votingStructure.votingStructureId;
        proposal.quorum = _quorum;
        proposal.proposalImplementationAddress = _proposalImplementationAddress;

        proposal.currentSession = 1;
        proposal.totalSessions = 1;

        proposal.tags = _tags;

        emit ProposalCreated(
            proposalId,
            proposal.description,
            proposal.proposingMemberAddress,
            proposal.proposingMemberChainId,
            proposal.proposingCommunityId,
            proposal.proposingCommunityName,
            proposal.proposalBudget,
            proposal.numberOfVotes,
            proposal.executed,
            proposal.passed,
            proposal.quorum,
            proposal.startTime,
            proposal.endTime,
            proposal.votingStructureId,
            proposal.proposalImplementationAddress,
            proposal.tags
        );
    }

    // ───────────────────────────────────────── Read
    function getProposalBasicInfoAndContraintsWithoutVotesById(uint256 proposalId)
        public
        view
        returns (ProposalBasicData memory proposalBasicData)
    {
        Proposal storage proposal = _proposals[proposalId];

        proposalBasicData.proposalId = proposal.id;
        proposalBasicData.description = proposal.description;
        proposalBasicData.proposingMemberAddress = proposal.proposingMemberAddress;
        proposalBasicData.proposingMemberChainId = proposal.proposingMemberChainId;
        proposalBasicData.proposingCommunityId = proposal.proposingCommunityId;
        proposalBasicData.proposingCommunityName = proposal.proposingCommunityName;
        proposalBasicData.proposalCommunityRestriction = uint(proposal.communityRestriction);
        proposalBasicData.startTime = proposal.startTime;
        proposalBasicData.endTime = proposal.endTime;
        proposalBasicData.votingStructureId = proposal.votingStructureId;
        proposalBasicData.tags = proposal.tags;
    }

    // ───────────────────────────────────────── Session Control
    function nextSession(uint proposalId) public {
        Proposal storage p = _proposals[proposalId];
        require(p.currentSession < p.totalSessions, "No more sessions");
        p.currentSession += 1;
    }

    // ───────────────────────────────────────── Cost stub
    function transferVoteCost(Vote memory /*voteData*/, uint /*cost*/) public pure returns (bool result) {
        return true;
    }

    // ───────────────────────────────────────── Vote
    function vote(Vote calldata voteData, uint /*communityId*/) public {
        Proposal storage proposal = _proposals[voteData.proposalId];
        VotingStructure memory votingStructure = _votingStructs[proposal.votingStructureId];

        require(block.timestamp >= proposal.startTime && block.timestamp <= proposal.endTime, "Voting not open.");

        // Limitler
        require(voteData.numericValue >= votingStructure.lowerLimit, "Below lowerLimit");
        require(
            votingStructure.upperLimit == 0 || voteData.numericValue <= votingStructure.upperLimit,
            "Above upperLimit"
        );

        // Yön (onlyYes)
        if (votingStructure.onlyYes) {
            require(voteData.yesno == true, "Direction restricted to YES");
        }

        // Repetition (onlyOnce) — session bazlı
        uint session = proposal.currentSession;
        bytes32 voterHash = _sessionKey(voteData.voterAddress, voteData.voterChainId, voteData.proposalId, session);
        if (votingStructure.onlyOnce) {
            require(proposal.voted[voterHash] == 0, "Already voted in this session.");
        }

        // Cost şeması
        VoteCostType voteCostType = votingStructure.voteCostType;
        require(
            voteCostType == VoteCostType.Free ||
            (voteCostType == VoteCostType.OneTokenPerVote      && transferVoteCost(voteData, 1)) ||
            (voteCostType == VoteCostType.SameAsVoteAmount     && transferVoteCost(voteData, voteData.numericValue)) ||
            (voteCostType == VoteCostType.Quadratic            && transferVoteCost(voteData, voteData.numericValue * voteData.numericValue)),
            "Vote cost failed"
        );

        // Kayıt
        uint newVoteId = _newVoteId();
        proposal.voted[voterHash] = newVoteId;
        proposal.votes[voterHash] = Vote({
            voteId: newVoteId,
            votingStructureId: voteData.votingStructureId,
            proposalId: voteData.proposalId,
            yesno: voteData.yesno,
            numericValue: voteData.numericValue,
            voterAddress: voteData.voterAddress,
            voterChainId: voteData.voterChainId,
            chainCurrentVotingWeight: voteData.chainCurrentVotingWeight,
            chainCurrentProposalVotingWeight: voteData.chainCurrentProposalVotingWeight,
            memberCurrentVotingWeight: voteData.memberCurrentVotingWeight,
            memberCurrentProposalVotingWeight: voteData.memberCurrentProposalVotingWeight,
            optionId: voteData.optionId
        });

        // YENİ: session + option (candidate) toplamını güncelle
        optionVotes[voteData.proposalId][session][voteData.optionId] += voteData.numericValue;

        proposal.numberOfVotes += 1;
        if (voteData.yesno) {
            proposal.numberOfYesVotes += 1;
            proposal.sumOfYesVotes += voteData.numericValue;
        } else {
            proposal.numberOfNoVotes += 1;
            proposal.sumOfNoVotes += voteData.numericValue;
        }

        proposal.executed = false;
        proposal.passed = false;
    }

    // ───────────────────────────────────────── Execute (placeholder)
    function executeProposal(uint256 proposalId) public {
        Proposal storage proposal = _proposals[proposalId];
        require(!proposal.executed, "Already executed.");
        require(block.timestamp > proposal.endTime, "Voting not ended.");
        proposal.executed = true;
        // proposal.passed = ... // quorum/sonuç kontrolü istenirse eklenir
    }

    // ───────────────────────────────────────── Getters (opsiyonel)
    function getProposalSessions(uint proposalId) external view returns (uint current, uint total) {
        Proposal storage p = _proposals[proposalId];
        return (p.currentSession, p.totalSessions);
    }

    function setProposalTotalSessions(uint proposalId, uint total) external {
        Proposal storage p = _proposals[proposalId];
        require(total >= 1, "invalid total");
        p.totalSessions = total;
        if (p.currentSession == 0) p.currentSession = 1;
    }

    function getVotingStructure(uint id) external view returns (VotingStructure memory) {
        return _votingStructs[id];
    }

    function getVoteGroup(uint id) external view returns (VoteGroup memory) {
        return _voteGroups[id];
    }
}