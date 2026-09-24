# PUB-GC native-time refinement adjudication after 0003

Status: **frozen before any 256/512-contribution qualification or NATIVE-TIME-0004 execution**

Publication owner: `PUB-GC`

Trigger:
`docs/publications/results/PUB-GC-NATIVE-TIME-0003.yaml`

## Evidence considered

NATIVE-TIME-0003 validly executed N0 through N5 for all five unchanged cases under the frozen adequacy criteria.

Four cases passed the N4-to-N5 fine-level guard. NT-H60 failed all four criteria, but the discrepancy magnitudes contracted consistently relative to the earlier N2-to-N3 comparison:

| metric | N2→N3 | N4→N5 | contraction factor |
| --- | ---: | ---: | ---: |
| cumulative exchange, cm | 5.32096144055138609e-4 | 1.36858420453418728e-4 | 3.8879 |
| max pressure head, cm | 2.88737144844631644e-1 | 7.40176679464923382e-2 | 3.9009 |
| max water content | 2.96980035731753134e-4 | 7.62873197245328427e-5 | 3.8929 |
| storage, cm | 5.32096144055138609e-4 | 1.36858420453522811e-4 | 3.8879 |

This contraction is descriptive evidence of regular refinement behaviour. It is **not** permission to extrapolate a passing result or to relax any threshold.

## Decision

Permit exactly one additional dyadic refinement pair before mandatory re-adjudication.

Extend the ladder with:

- N6: 256 x 0.00015625 d;
- N7: 512 x 0.000078125 d.

The fine-level stability guard becomes N6 versus N7.

If N6 versus N7 passes all four existing criteria for all five unchanged cases:

1. use N7 only as the supporting numerical reference for this native-time adequacy study;
2. compare N0 through N6 against N7;
3. select the coarsest level passing all four existing criteria in every case.

If N6 versus N7 fails any criterion in any case:

- return `NO_POLICY_SELECTED_FINE_LEVEL_UNSTABLE`;
- do not extend to N8/N9 automatically;
- freeze a new scientific decision that re-examines the adequacy strategy, fixture severity, and reference construction before any further refinement.

## Required precondition

Before NATIVE-TIME-0004 may execute, the unchanged research-only macro-window response must be separately qualified for 256 and 512 native contributions, including a shifted-absolute-time 512-contribution fixture.

This qualification may test only temporal/envelope validity and preservation of the existing macro-response invariants. Its hydrologic values may not be used for native-time policy selection.

## Frozen unchanged content

Retain unchanged:

- NT-C0, NT-W3, NT-D05, NT-R3 and NT-H60;
- all initial state and forcing definitions;
- cumulative exchange tolerance 1e-4 cm;
- maximum endpoint pressure-head tolerance 1e-2 cm;
- maximum endpoint water-content tolerance 1e-5;
- endpoint storage tolerance 1e-4 cm;
- coarsest-passing selection rule;
- terminal-surrogate mismatch exclusion;
- H2/H3 exclusion.

## Interpretation boundary

This is supporting numerical-control work. It neither establishes nor tests H2/H3 and does not create a universal SWAP timestep recommendation.

The observed near-fourfold contraction is used only to justify one bounded additional refinement pair, not to infer the result of that refinement.
