# F-PE-TIMEARCH07 result — production timestep decision trace

Date: 2026-09-28

Status: `QUALIFIED_PRODUCTION_TIMESTEP_DECISION_TRACE`

Canonical base:

`integration/f-ci-canonical@70be0aeca1485dd626749d34e5c46aba166e2eb5`

Qualified branch head:

`f040cce0dff150b78aefda7f269c87367a30e822`

Primary evidence:

- TIMEARCH07 workflow run `36426602479`;
- job `108941988088`;
- conclusion: SUCCESS.

## Production change

TIMEARCH07 adds worker-local timestep-decision provenance to `a23bu_worker_context_t`.

The trace records:

- input dt;
- preferred dt before event clipping;
- executed dt after event clipping;
- TIMEARCH06 proposal/retry reason;
- generic limiting reason;
- whether a hard event clipped the preferred dt.

`TimeControl` receives the already existing optional worker through the SWAP call path and records provenance only when a worker is present.

Standalone execution remains valid without a worker.

## Ownership

The trace is:

- worker-local;
- diagnostic only;
- resettable;
- never persistent physical state;
- never read back by TimeControl or the decision service to choose dt.

No module-global mutable timestep trace was introduced.

## Exact behavior preservation

The TIMEARCH06 production decision-service gate remains green.

The TIMEARCH03 preservation bank remains exactly preserved on all 20 hydraulic/regime cases.

Aggregate preserved authority remains:

- accepted steps: 186;
- attempted intervals: 188;
- solver retries: 2;
- deterministic work: 3259;
- DTMAX hit fraction: 48.4%;
- shadow above DTMAX fraction: 41.9%.

No physical trajectory or timestep sequence changed.

## Worker-local evidence

The existing multi-worker OpenMP context gate was extended with timestep-trace writes and resets.

Results:

- O0: PASS;
- O2: PASS;
- O0/O2 output identity: PASS;
- 8 workers x 1000 repeated checks;
- no cross-worker trace contamination detected.

## Trace semantics

### Accepted-step path

For `TimeControl(3)`:

- trace input dt is captured before TIMEARCH06 proposal;
- trace preferred dt is the TIMEARCH06 service result;
- event clipping executes exactly as before;
- trace executed dt is recorded after the existing event clamp;
- hard-event limiting provenance is recorded only if the clamp reduced dt.

### Solver-retry path

For `TimeControl(5)`:

- trace input dt is captured before retry decision;
- preferred/executed dt is the unchanged TIMEARCH06 retry result;
- retry versus retry-floor reason is preserved.

## Decision

`QUALIFIED_PRODUCTION_TIMESTEP_DECISION_TRACE`

TIMEARCH07 adds observability only.

No new timestep policy is admitted.
