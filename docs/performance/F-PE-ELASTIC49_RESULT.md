# F-PE-ELASTIC49 — Reference temporal identity-policy attribution result

Date: 2026-09-29

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic49-temporal-identity-policy`

Qualified postimage:
`6eed9980ee0dc5f8da45ff8e4276fa15b559dc3f`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36622577060`

Job:
`109591415366`

Conclusion:
SUCCESS.

## Question

What does the active `TX_TEMPORAL_EXTERNAL_FULL_HALF` gate actually measure on
the admitted serialized Reference route?

## Qualified source-policy finding

The Reference temporal metric is identity-only.

In
`src/runtime/mod_fmr_serialized_reference_backend.f90`,
`fmr_serialized_temporal_identity` compares full-step and two-half-step state
using exact equality for:

- pressure head;
- water content;
- ponding depth;
- groundwater level;

plus optional-state allocation/layout identity where applicable.

If those state components are exactly equal, the function returns:

`0.0_real64`.

If they are not exactly equal, the function retains:

`huge(0.0_real64)`.

There is no continuous head norm, water-content norm, scaled residual, relative
error or epsilon-based comparison in this temporal metric.

## Transaction acceptance

In
`src/transaction/mod_transaction_reference.f90`,
the transaction core computes:

`terr = model%temporal_error(full_state, half_state)`

and then:

`temporal_ok = terr <= policy%temporal_tolerance`.

For the Reference route audited here, this means the configured
`temporal_tolerance = 1e-6` does not operate as a conventional physical error
band.

The effective behavior is binary:

- exact full/two-half state identity -> `terr = 0` -> temporal pass;
- any relevant state mismatch -> `terr = huge()` -> temporal reject.

A temporal rejection triggers rollback/retry through the normal transaction
policy.

## Qualification evidence

Workflow run `36622577060`, job `109591415366` passed:

- exact pressure-head comparison: PASS;
- exact water-content comparison: PASS;
- exact ponding-depth comparison: PASS;
- exact groundwater-level comparison: PASS;
- equal state returns zero: PASS;
- mismatch retains huge sentinel: PASS;
- transaction compares temporal error to policy tolerance: PASS;
- temporal rejection counter and retry path present: PASS;
- no continuous-error machinery in the bounded Reference temporal function:
  PASS;
- zero `src/**` change: PASS.

## Relation to ELASTIC47 and ELASTIC48

ELASTIC47 established that reducing requested interval duration from
`0.25` to `0.015625 day` did not make any of the 180 difficult perturbed
cases complete.

ELASTIC48 established that active ELAS often removes nonlinear solver failures
and exposes temporal rejection as the next dominant limiter.

ELASTIC49 explains why that temporal limiter is unusually strict:

the full and two-half trajectories are not being judged by a small-error norm.
They are being judged by exact state identity.

Therefore a smaller timestep only helps if it makes the full and two-half
postimages bit-identical. A merely small physical discrepancy still fails the
temporal gate.

## Hypotheses

H1, Reference temporal metric is identity-only:
SUPPORTED.

H2, transaction acceptance applies the configured tolerance to that binary
metric:
SUPPORTED.

## Interpretation

The current `1e-6` temporal tolerance is numerically present but effectively
non-scaling on this Reference/full-half route.

This does not establish that exact identity is wrong in every context.
It establishes that the current gate cannot distinguish:
- a tiny physically harmless full/half discrepancy;
- a materially large temporal discrepancy.

Both are represented as `huge()`.

That is the mechanistic reason why the ELAS-improved nonlinear path can still
be rejected by the temporal layer even after substantial timestep reduction.

## Decision

Classification:
`QUALIFIED_REFERENCE_TEMPORAL_IDENTITY_GATE`.

No production policy change is authorized by ELASTIC49.

The next bounded research step is to measure the actual full-versus-two-half
state discrepancy by component on the difficult active-ELAS cases and evaluate
candidate physically scaled error measures.

Only after that measurement should a replacement temporal metric, tolerance or
controller policy be proposed.
