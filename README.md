# DAO Governance Parameter Space

A formal seven-dimensional parameter space taxonomy for DAO voting mechanisms, with a configurable Solidity implementation and reproducible Foundry gas benchmarks.

## Paper

**Title:** A Formal Parameter Space Taxonomy for DAO Voting Mechanisms: Design, Implementation, and Gas-Evaluated Reproducible Benchmarking

**Author:** Ferda Özdemir Sönmez — Visiting Academic, Department of Computing, Imperial College London

**Submitted to:** Turkish Journal of Electrical Engineering and Computer Sciences (TJEECS)

## Repository Structure

```
code/
  src/
    GenericVoting.sol                  # Interface
    GenericVotingContractImpl.sol      # Full implementation (7 dimensions)
  test/
    GenericVoting.t.sol                # Foundry unit tests
    GenericVoting_JSONRunner.t.sol     # JSON-driven scenario runner
    data/
      Simple_YesNo_Voting.json             # Scenario 1: Plurality (1-cand)
      Token_Based_Voting.json              # Scenario 2: Share majority
      Ranked_MultiCandidate_Voting.json    # Scenario 3: Ranked multi-candidate
      Quadratic_Voting.json                # Scenario 4: Quadratic
      Baldwin_Voting.json                  # Scenario 5: Baldwin's Method
      Token_Approval_Voting.json           # Scenario 6: Token approval
```

## Seven Taxonomy Dimensions

| Dim | Name | Values |
|-----|------|--------|
| D1 | Candidate Structure | Single, Multi, Dynamic |
| D2 | Voting Direction | ApprovalOnly, ApprovalOrRejection |
| D3 | Cost Model | Free, OneTokenPerVote, SameAsVoteAmount, Quadratic |
| D4 | Weight Scheme | Equal, ShareBased, TokenBased |
| D5 | Session Config | 1 … N |
| D6 | Community Restriction | All, OnlyProposing, Children, ProposingAndChildren |
| D7 | Repetition | Yes, No |

## Scenario-to-Parameter Mapping

| No. | Scenario | D1 | D2 | D3 | D4 | D5 | D6 | D7 |
|-----|----------|----|----|----|----|----|----|-----|
| 1 | Plurality (1-cand) | Single | AO | One | Eq | 1 | All | No |
| 2 | Share majority | Single | A/R | Free | Sh | 1 | Prop | No |
| 3 | Ranked multi-cand | Multi | AO | Same | Tk | N-1 | Ch | No |
| 4 | Quadratic | Single | AO | Quad | Eq | 1 | P+C | No |
| 5 | Baldwin's Method | Multi | AO | Free | Eq | N-1 | All | Yes |
| 6 | Token approval | Dynamic | AO | Free | Eq | 1 | All | Yes |

## Gas Benchmarks

Benchmarks run with Foundry on 16 October 2026. ETH/USD: $2,413.72, gas price: 0.143 gwei.

| Function | Sc.1 | Sc.2 | Sc.3 | Sc.4 |
|----------|------|------|------|------|
| createProposal | $0.1705 | $0.1800 | $0.1705 | $0.2084 |
| vote | $0.03853 | $0.07450 | $0.04540 | $0.15446 |

## Running Tests

```bash
cd code
forge test -vv
```

## License

MIT
