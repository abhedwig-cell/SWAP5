# F-MIG431-LOW01-A state and timing contract

Date: 2026-10-01

Status: FROZEN_BEFORE_IMPLEMENTATION
Branch: `work/f-mig431-low01a-qgwl-boundary`
Original preregistration: `a32a23e0af8920a8b29aeebca8ae916bdea4d9c8`
Original canonical base: `8bb835a065248aad06b18a3b563234b20033ba0d`
Reconciled canonical: `ae3c7a9ba4a9ab741992be965448cf633820d2a1`

## Reconcile

Canonical advanced by three commits from the preregistered base. The complete delta is PPA-WU05 PERCH21 result/status/closeout evidence. No lower-boundary ABI, qbot sign, transaction, checkpoint, mass-owner, groundwater datum, parser or SWBOTB=4 semantic surface changed. LOW01-A may therefore continue without a shared-authority repair.

The previous `F-MIG431-LOW01A_SOURCE_AUTHORITY_BLOCKER.md` is superseded as an execution stop. The exact distribution identity and source-member hashes remain useful provenance, while the already extracted SWAP 4.3.1 code inventory plus source-bound PPA-WU02 audit close the parser/domain facts required here.

## Frozen scientific law

Legacy selector `SWBOTB=4` has two submodes selected by `SWQHBOT`:

1. `SWQHBOT=1`: exponential relation
   `qbot = COFQHA * exp(COFQHB * abs(gwl)) + COFQHC`.
2. `SWQHBOT=2`: tabulated q(h) relation using `HTAB` as groundwater level and `QTAB` as qbot.

Native units:
- `gwl`, `HTAB`: cm relative to soil surface, negative below surface;
- `COFQHA`, `COFQHC`, `QTAB`, result `qbot`: cm d-1;
- `COFQHB`: cm-1;
- native qbot sign is positive upward/into the soil profile and negative downward/out of the profile, matching the admitted generic qbot owner.

Parser/source domains recovered from the exact 4.3.1 code inventory:
- `SWQHBOT`: integer 1..2;
- `COFQHA`: -100..100 cm d-1;
- `COFQHB`: -1..1 cm-1;
- optional `COFQHC`: -10..10 cm d-1;
- `HTAB`: -1.0e4..0 cm in 4.3.1;
- `QTAB`: -100..100 cm d-1.

The optional C term is an additive flux. Its historical purpose is to permit a vertical offset, including upward seepage, without changing the exponential curve shape.

## State and timing

The q(gwl) law is evaluated before the Richards solve. It consumes the profile groundwater-level state that exists at the start of the physical trial.

SWAP 4.3.1 `SoilWater(task=2)` first snapshots `gwlm1=gwl` together with h/theta/pond. The accepted new groundwater level is not calculated until `SoilWater(task=3)`, after the physical solve has succeeded. On reset/retry `gwl=gwlm1` is restored.

Therefore LOW01-A freezes the following semantics:

- provider input is the committed/start-of-trial groundwater level, not a candidate groundwater level generated inside the current solve;
- qbot is constant for that Richards trial;
- a failed/rejected trial cannot advance the groundwater level used by a retry;
- retry from the same checkpoint re-evaluates the same q(gwl) value;
- only after accepted physical state publication may the newly calculated groundwater level become the input to the next physical trial.

This is the legacy lagging semantics. LOW01-A must not introduce an implicit q(gwl) Jacobian or candidate-state feedback.

## Table semantics

The table is a groundwater-level to qbot lookup, not a time series. The production provider requires a non-empty finite table with equal-sized h/q arrays and a strictly monotone h axis. It performs piecewise-linear interpolation between adjacent source points and endpoint clamping outside the table range, matching the legacy AFGEN lookup contract. Descending legacy HTAB order is accepted directly; ascending order is also accepted as the same mathematical table.

No extrapolated slope is applied beyond an endpoint.

## Fail closed

The typed provider returns unavailable/invalid and must not publish qbot for:
- selector outside 1..2;
- non-finite groundwater level or coefficients/table values;
- coefficient values outside the exact parser domains;
- empty/mismatched table arrays;
- HTAB outside -1e4..0 cm;
- QTAB outside -100..100 cm d-1;
- duplicate or non-monotone HTAB points;
- non-finite exponential result.

LOW01-A does not alter general SWP/BBC parsing. A caller/application adapter must materialize this already-validated typed configuration.

## Binding

The provider result binds to the already admitted generic prescribed-qbot Richards row as typed `bottom_mode=2`. No generic solver request/result ABI, bottom-boundary ABI, qbot sign, mass ledger or accepted-state owner changes.

This contract owns only SWBOTB=4.
