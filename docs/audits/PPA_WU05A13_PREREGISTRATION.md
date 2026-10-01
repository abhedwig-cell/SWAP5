# PPA-WU05-A13 preregistration — accepted-state macropore seed

Date: 2026-10-01

Status: `PREREGISTERED / OUTER-COUPLING_REPAIR`

Baseline: `work/ppa-wu05-a12-fmr-perched-runtime@812496a6f73361849507c151d876d78b4cc3b4ab`

Canonical reconciliation point: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

## Purpose

Test whether the current serialized outer macropore coupling can preserve transient
source-faithful perched topology by replacing the zero-exchange first predictor with a
deterministic accepted-state macropore exchange seed.

This workunit does **not** move macropore physics into the inner Reference-Richards
nonlinear loop.

## Hypothesis

Before the first Richards solve, the runtime can:

1. derive current macropore storage from accepted macropore state;
2. compose the existing A11/A6 rate request from the accepted matrix physical state;
3. evaluate the existing A6 bundle;
4. use the resulting `qexc_to_matrix_rate` as the initial exchange overlay;
5. run the normal predictor/corrector sequence unchanged thereafter.

If this keeps a transient perched lens alive long enough for the normal outer corrector to
converge, active perched exchange may be qualified without an inner-Richards architecture
change.

## Hard constraints

A13 must preserve:

- seven-field macropore continuation-state ownership;
- rejected-trial isolation;
- restart semantics;
- existing A8/A9/A10 top-input and rapid-drain behavior;
- A11 exact `CritUndSatVol` carrier semantics;
- Full Richards as production reference;
- current mass tolerances and balance accounting.

The accepted-state seed is recomputable worker/trial scratch. It is not persistent state.

## Gates

### G1 — deterministic accepted-state seed

For an A11 perched-active accepted matrix state, the seed must produce:

- non-empty perched view;
- positive `QInIntSat`;
- finite domain/node exchange vector;
- unchanged accepted committed state.

### G2 — real serialized active runtime

The A12 layered perched fixture must complete with:

- a nonzero accepted-state seed;
- a nonzero active perched runtime receipt;
- no mass-tolerance weakening;
- complete mass accounting.

### G3 — reject/replay and restart

The existing A12 transaction harness must pass candidate isolation, discard/replay,
commit, persistence export/restore and next-interval replay.

### G4 — preservation

A11 source/carrier and A10 preservation gates remain green.

### G5 — decision

If G1-G4 pass on one persisted postimage:
`QUALIFIED_OUTER_COUPLING_PERCHED_PRODUCTION_ADMISSION_CANDIDATE`.

If the seeded predictor still loses the source-defined perched path or cannot converge
without weakening accepted numerical/mass contracts:
`FALSIFIED_ACCEPTED_STATE_SEED`, and the next architecture boundary is explicit
inner-Richards macropore coupling.

## Non-scope

- no new continuation fields;
- no arbitrary/multiple rapid-drain levels;
- no covering-layer extension;
- no within-corrector dynamic crack displacement;
- no RossFast;
- no parallel MultiSWAP;
- no inner-Newton macropore callback.
