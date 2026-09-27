# F-PE-REPRO01 D1 — first-corrector isolation

Date: 2026-09-26

Status: `PREREGISTERED_OBSERVATION_ONLY`

## Question

Does exact/default status 6 remain when the live test is reduced to:

`FGC44 initialize -> first SWAP corrector trial at href`

with no MODFLOW solve loop?

## Rationale

The fixed-build failures all occurred at the first Python call:

`swap.trial(href)`

before a coupled MODFLOW iteration produced a new head.

Therefore the first diagnostic reduction removes MODFLOW/XMI execution after SWAP initialization while preserving:

- the same FGC44 exact bridge;
- the same initialized committed state;
- the same predicted reference head `href`;
- the same captured participant origin;
- the same first corrector request.

If the reduced probe still fails intermittently, the failure is upstream of the MODFLOW coupling loop.

## Protocol

Compile the exact/default FGC44 SWAP bridge once.

Execute 40 fresh Python processes.

Each process:

1. loads the same compiled bridge;
2. calls `initialize()`;
3. records `href`;
4. calls exactly one `trial(href)`;
5. records PASS/FAIL and backend observation;
6. exits without commit.

No A1.

No A2C.

No performance timing claim.

## Diagnostic observation

After the first trial attempt expose, from the test bridge only:

- solver executed;
- solver status;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- internal retries;
- constitutive evaluations;
- temporal indicator status/availability;
- temporal head bound;
- top flux;
- bottom flux;
- equation residual availability/value;
- practical A2C flag.

The bridge instrumentation must not mutate model state.

## Decision

If the reduced exact probe still shows status 6, MODFLOW/XMI coupled iteration is excluded as the direct trigger and D2 focuses on SWAP transaction/solver state.

If all 40 probes pass, the nondeterminism requires a later step in the full live test and D2 restores one coupling component at a time.
