# PPA-WU05-PERCH19 preregistration — source-faithful FrReduQ retry state machine

Date: 2026-10-01

Status: `PREREGISTERED / NUMERICAL_STATE_MACHINE_RESEARCH`

Research baseline:
`research/ppa-wu05-a18-perched-authority-fixture@77f47a7d98cece4b371fdf078525a7ade7daec4a`

Current canonical reconciliation:
`integration/f-ci-canonical@8bfff34e5bf06817f63a571282f70436cd90ede2`.

Namespace note:

The historical perched A11-A18 ancestry conflicts with later canonical RFM use of generic
`PPA-WU05-A11...` paths. PERCH19 therefore uses the distinct
`PPA-WU05-PERCH*` namespace.

No historical perched A11-A18 documentation is to be merged wholesale into canonical.

## Purpose

Recover and qualify the exact SWAP 4.3.1 macropore convergence-reduction controller around
`IDecMpRat` / `FrReduQ`, preserving SWAP5 transaction ownership.

A18 proved that the source-backed Andelst perched fixture can require a reduced exchange
factor for a fixed `dt=0.002 d` inner solve. PERCH19 must now establish the actual legacy
ordering rather than hardcoding the first successful factor.

## Exact source controller

B1.11 defines:

`FrReduQ = 0.1 ** IDecMpRat`

with bounded levels:

- `IDecMpRat=0 -> 1.0`;
- `IDecMpRat=1 -> 0.1`;
- `IDecMpRat=2 -> 0.01`;
- `IDecMpRat=3 -> 0.001`.

On nonlinear failure:

1. if the timestep is not yet at `DTMIN`, ordinary timestep reduction owns the retry;
2. only at `DTMIN`, if macropores are active and `IDecMpRat<3`, increment
   `IDecMpRat` and retry with reduced exchange;
3. if level 3 also fails, ordinary non-convergence handling applies.

On convergence with `IDecMpRat>0`:

- increment successful-step counter `NStep` up to 10;
- when `dt > dtold` or `NStep >= 10`, reset `NStep=0` and decrement
  `IDecMpRat` by one.

When the macropore reduction retry is selected, legacy TimeControl sets the next trial
step to `sqrt(DTMIN*DTMAX)`.

## Research questions

### Q1 — ownership

Determine whether the SWAP5 equivalent belongs in:

- solver diagnostics;
- transaction/execution policy;
- numerical continuation state;
- or a combination.

The physical seven-field macropore continuation state must not own this controller.

### Q2 — rejected-trial isolation

A failed attempt at one reduction level must not mutate accepted physical state.

Any reduction-level transition must be trial/execution policy state only.

### Q3 — persistence and restart

Because legacy `IDecMpRat`, `NStep` and `dtold` persist across accepted steps,
PERCH19 must decide whether source-faithful production requires an explicit numerical
continuation payload.

Do not silently drop recovery semantics merely because A18's single-interval case passes.

### Q4 — temporal ordering

Prove that exchange reduction is not selected before ordinary timestep reduction reaches
its source-equivalent minimum-step condition.

### Q5 — bounded ladder

At the minimum-step boundary, prove deterministic transitions:

`1 -> 0.1 -> 0.01 -> 0.001 -> terminal failure`.

### Q6 — recovery

Prove the source decrement rule after successful accepted steps, including the ten-step
counter and `dt > dtold` condition.

## A18 fixture use

The A18 Andelst fixture remains the active perched physical authority.

It may be used to show that a reduction level can recover an inner solve, but PERCH19 must
not claim source-faithful production admission from that alone unless temporal ordering
and cross-step recovery state are also represented.

## Decision states

- `QUALIFIED_SOURCE_FAITHFUL_FRREDUQ_STATE_MACHINE`;
- `QUALIFIED_RETRY_LADDER_REQUIRES_NUMERICAL_CONTINUATION_STATE`;
- `PARTIAL_CONTROLLER_ONLY`;
- or `FALSIFIED_FRREDUQ_MIGRATION_ROUTE`.

## Canonical rule

PERCH19 is research on the historical perched ancestry.

If it reaches a production-admission candidate, reconstruct the required implementation
from the then-current `integration/f-ci-canonical`, carrying only explicitly qualified
code and new PERCH evidence.
