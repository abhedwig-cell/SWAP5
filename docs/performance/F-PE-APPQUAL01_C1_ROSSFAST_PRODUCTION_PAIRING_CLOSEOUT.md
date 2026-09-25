# F-PE-APPQUAL01 C1 RossFast production pairing closeout

Date: 2026-09-25

Status: `BLOCKED_BY_REFERENCE_PRODUCTION_TEMPORAL_POLICY`

## Question

Can the existing production bootstrap execute the same non-trivial B01 physical workload with:

- Reference Richards; and
- RossFast D3R,

so that APPQUAL01 can measure an application-level production speed ratio at 100, 1,000 and 10,000 columns?

## Result

Not yet.

The attempted paired workload fails before any valid Reference production timing can be obtained.

Observed on APPQUAL01 diagnostic run:

- production bootstrap initialization succeeds;
- column profile is reported `ADMITTED`;
- runtime returns `FMR_APP_BOOT_RUNTIME_FAILED`;
- first column has `kernel_status=2`;
- `kernel_status=2` maps to `CANONICAL_STATUS_TRANSACTION_FAILED`;
- `accepted_substeps=0`;
- no valid production result is committed.

This is therefore not evidence that RossFast itself fails or is slow.

## Root cause

The current serialized Reference route with:

- `FMR_NUMERICAL_CONTINUATION_NONE`; and
- `TX_TEMPORAL_EXTERNAL_FULL_HALF`

uses `fmr_serialized_temporal_identity` as its temporal comparison.

For the base physical state this function returns:

- 0 only when the full-step and two-half-step states are bit-identical for pressure head, water content, ponding and groundwater level;
- `huge()` otherwise.

Consequently a genuinely evolving B01 forcing trajectory is not an admissible ordinary Reference production interval under this route, even though Reference Richards itself solves the same fixed interval successfully in the F-ROSS15 solver-level authority.

The earlier B1 Reference scaling workload passed because it was intentionally near-identity/equilibrium-like and therefore satisfied this exact temporal identity route.

## Scientific interpretation

There are currently two distinct authorities:

### Solver-level common domain

F-ROSS15 demonstrates a paired Reference/RossFast domain for fixed-interval solves and qualifies differences in:

- pressure head;
- water content;
- storage.

This remains valid solver-level evidence.

### Production transaction domain

APPQUAL01 shows that the same kind of non-trivial fixed-interval B01 workload cannot yet be compared fairly through the current production transaction layer because Reference production temporal acceptance is restricted to exact state identity when no richer continuation/certificate is configured.

Therefore:

> solver-level paired validity does not imply production-transaction paired validity.

## What is not allowed

Do not obtain a RossFast speedup by:

- weakening Reference tolerance until the case happens to pass;
- disabling temporal qualification only for benchmarking;
- comparing RossFast production runtime with a non-production Reference inner-solver timing;
- changing forcing/state separately by route.

Any such number would mix algorithmic and governance differences and would not be an APPQUAL01 production comparison.

## Next legitimate routes

1. Keep F-ROSS15 as the solver-level Reference/RossFast performance authority.
2. Keep APPQUAL01 B1 Reference as the large-N production scaling authority.
3. Open a separate Reference production temporal work item to provide a scientifically meaningful non-trivial temporal acceptance route.
4. Only after that route is admitted, repeat the B01 production pairing.
5. Alternatively identify an already-admitted common production workload that evolves non-trivially under both solvers without modifying either route's acceptance semantics.

## Current performance baseline retained

The cleaned Reference B1 scaling observation remains:

- S100: 0.001232278 s;
- S1000: 0.010608947 s;
- S10000: 0.106024102 s;
- approximately 10.60 microseconds/column at S10000;
- maximum reported mass residual 0.

These are workload-specific shared-runner observations.

## Closeout classification

`NEGATIVE_RESULT / ARCHITECTURAL_BLOCKER`

The RossFast production challenger is not rejected.

The attempted direct production pairing is blocked by the current Reference temporal-control semantics.
