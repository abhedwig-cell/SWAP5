# F-PE-TEMPORAL08 P2 result

Date: 2026-09-27

Status: `PASS_BOUNDED_PRODUCTION_BOOTSTRAP_BINDING`

Harness:

`tests/fpe/run_fpe_temporal08_p2_bootstrap.sh`

Current-head authority:

- production-code head exercised: `d97b607ec36457e9b9ebaf9b798b7fe672421a98`;
- workflow run: `36300393644`;
- job: `p2-bootstrap-binding`;
- conclusion: PASS.

## Bounded binding

The production bootstrap enables the frozen history-aware policy only when all of the following hold:

- admitted groundwater profile;
- `bottom_mode = 5`;
- Richards temporal-history continuation;
- model-certificate temporal acceptance;
- seeded, finite predecessor right derivative.

Frozen parameters:

- coefficient = `0.65`;
- floor = `1e-5 cm`.

Missing or nonfinite seeded history is rejected before runtime.

## Hot-path ownership

The predecessor derivative is reduced to one scalar history scale at accepted-origin capture.

Repeated corrector trials do not resnapshot committed state to resolve the temporal budget.

The scalar is cleared on:

- origin abandon;
- successful candidate commit.

Thus the cached value is bound to the accepted origin and cannot cross lineage/revision ownership.

## Production preservation

The unchanged PPA-WU01 production application bootstrap passes at O0 and O2.

Preserved gates include:

- standalone Reference runtime;
- hard mass;
- Fortran committed-state ownership;
- participant-registry ownership;
- mass-ledger ownership;
- F-GC49D context from production owner;
- no qualification-fixture promotion;
- unadmitted profile fail-closed;
- groundwater root-extraction fail-closed;
- groundwater drainage-response fail-closed;
- active-process composition fail-closed.

## Decision

P2 passes.

The c=0.65 policy is bound only to the qualified groundwater production profile, with default behavior preserved elsewhere.
