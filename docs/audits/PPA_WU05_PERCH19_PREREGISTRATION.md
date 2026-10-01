# PPA-WU05-PERCH19 preregistration — source-faithful FrReduQ retry ladder

Date: 2026-10-01

Status: `PREREGISTERED / PERCHED_PRODUCTION_RECOVERY_POLICY`

Research baseline:
`research/ppa-wu05-a18-perched-authority-fixture@0988aa61b0467923f4b0dcdde4a8a83156a18d5e`.

Current canonical reconciliation:
`integration/f-ci-canonical@f477f3fb7bf272757ac7a764bf9492883a521754`.

This research branch is intentionally not an admission branch. A18 established a namespace
collision with a later canonical RFM `PPA-WU05-A11`; eventual perched admission must be
reconstructed from then-current canonical under the `PPA-WU05-PERCH*` namespace.

## Source authority

Exact SWAP 4.3.1/B1.11 owns the bounded macropore convergence reduction state:

`IDecMpRat = 0..3`

with:

`FrReduQ = 0.1 ** IDecMpRat`.

The exact factor ladder is therefore:

`[1.0, 0.1, 0.01, 0.001]`.

A18 proved on the source-backed 112-node Andelst perched fixture that:

- factor 1.0 requests retry;
- factor 0.1 converges;
- accepted active perched exchange is nonzero;
- internal and macropore mass residuals are zero.

A fixed production setting of 0.1 is therefore forbidden.

## Purpose

Represent the exact bounded reduction ladder as trial-local numerical policy for the A17
inner-Richards macropore route.

The ladder is a recovery mechanism, not persistent physical state.

## Required semantics

For an inner-Richards macropore trial:

1. start every new trial at factor 1.0;
2. evaluate the normal solver attempt;
3. only when that attempt returns retry/non-convergence, discard all candidate/scratch
   effects and retry from the same accepted matrix and seven-field macropore state at the
   next exact source factor;
4. stop at the first converged factor;
5. fail/retry after 0.001 if no factor converges.

Every attempt must rebuild the provider from accepted authority. No failed attempt may
become the base state of the next reduction level.

## Gates

### G1 — exact factor sequence

A controlled provider/solver fixture must observe exactly:

`1.0 -> 0.1 -> 0.01 -> 0.001`

with no intermediate factor and no factor below 0.001.

### G2 — accepted-state replay

Each reduction attempt starts from bitwise-identical accepted matrix and seven-field
macropore state.

Rejected attempts publish no history, candidate storage, restart or committed state.

### G3 — A18 Andelst authority

On the exact 112-node source-backed perched fixture:

- factor 1.0 must fail/retry;
- factor 0.1 must be selected automatically;
- final active perched exchange and macropore storage gain must match the A18 fixed-factor
  qualification within its existing numerical tolerances;
- internal exchange and macropore mass residuals must pass unchanged.

### G4 — deterministic replay/restart

The automatically selected factor is a diagnostic of the accepted attempt, not persistent
physics. Replaying from the same checkpoint must select the same factor and reproduce the
same accepted candidate.

Restart after acceptance must not require serializing the reduction index.

### G5 — preservation

When the inner-Richards route is disabled, A8/A9/A10 behavior remains unchanged.

A15 derivative, corrected perched carrier, A16 callback and A17 transaction infrastructure
remain green on their qualified dependency surfaces.

## Non-scope

- no covering-layer extension;
- no dynamic crack continuation update inside Newton;
- no RossFast;
- no parallel MultiSWAP;
- no canonical admission from this research ancestry.

## Decision states

- `QUALIFIED_SOURCE_FAITHFUL_FRREDUQ_RETRY_LADDER`;
- `PARTIAL_LADDER_REQUIRES_TRANSACTION_CONTROLLER_EXTENSION`;
- or `FALSIFIED_FRREDUQ_RETRY_LADDER`.

A production-admission reconstruction from current canonical is permitted only after the
first state is reached.
