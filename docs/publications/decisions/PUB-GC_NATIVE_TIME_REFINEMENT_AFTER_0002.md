# PUB-GC native-time refinement adjudication after 0002

Status: **frozen before finer qualification or execution**

Publication owner: `PUB-GC`

Trigger:
`docs/publications/results/PUB-GC-NATIVE-TIME-0002.yaml`

## Decision

NATIVE-TIME-0002 validly executed all N0-N3 trajectories, but the frozen NT-H60 case failed every N2-to-N3 adequacy criterion. Therefore:

- do not select a native integration policy;
- do not remove NT-H60;
- do not relax any adequacy threshold;
- do not use terminal-surrogate mismatch as a stopping or selection criterion;
- extend the dyadic native-time ladder.

The next ladder is:

- N0: 4 x 0.01000 d;
- N1: 8 x 0.00500 d;
- N2: 16 x 0.00250 d;
- N3: 32 x 0.00125 d;
- N4: 64 x 0.000625 d;
- N5: 128 x 0.0003125 d.

The next fine-level stability guard is N4 versus N5. If it passes for all five unchanged qualification-only cases, compare N0 through N4 against N5 and select the coarsest level passing all four existing adequacy thresholds in every case.

If N4 versus N5 is unstable in any case, return NO_POLICY_SELECTED_FINE_LEVEL_UNSTABLE and freeze another decision before further refinement.

## Required precondition

Before executing the six-level native-time study, the already requalified research macro-window component must be separately shown to handle 64 and 128 native contributions while preserving temporal closure and all prior qualification invariants.

This is an envelope qualification only. It may not use or tune hydrologic native-time outcomes.

## Frozen unchanged content

The following are inherited unchanged from NATIVE-TIME-0001/0002:

- initial state and common fixture;
- NT-C0, NT-W3, NT-D05, NT-R3 and NT-H60;
- cumulative exchange tolerance 1e-4 cm;
- maximum endpoint pressure-head tolerance 1e-2 cm;
- maximum endpoint water-content tolerance 1e-5;
- endpoint storage tolerance 1e-4 cm;
- coarsest-passing policy rule;
- H2/H3 exclusion;
- terminal-surrogate mismatch exclusion.

## Interpretation boundary

This refinement is supporting numerical-control work. It does not test H2 or H3 and does not create a universal SWAP timestep recommendation.
