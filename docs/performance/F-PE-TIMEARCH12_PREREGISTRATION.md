# F-PE-TIMEARCH12 preregistration — AUTO_REFERENCE algorithm discovery

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@eb3a5718a5b7b0b24ebe744e595b781882e7f25a`

Parent authority:

- TIMEARCH01: timestep architecture redesign qualified;
- TIMEARCH06: accepted-step/retry decision service extracted;
- TIMEARCH07: production decision trace;
- TIMEARCH08: preferred-step memory separated from event-clipped execution;
- TIMEARCH09: user DTMAX demoted to optional expert safety ceiling and DTMIN to internal retry floor;
- TIMEARCH10: LEGACY_NUMERICS / AUTO_REFERENCE configuration seam;
- TIMEARCH11: AUTO_REFERENCE controller interface, fail-closed until controller admission.

## Purpose

Discover whether a controller that no longer uses a normal operating DTMAX can outperform LEGACY_NUMERICS while preserving bounded physical behavior.

This is algorithm discovery, not production admission.

## Design constraints

The candidate must:

- use no soil/material/regime identifier;
- use no required user DTMAX;
- use no required user DTMIN;
- treat the retry floor as solver safety only;
- preserve exact hard-event clipping outside the proposal algorithm;
- update proposal memory only after committed accepted steps;
- leave rejected trials out of accepted-history adaptation.

## Candidate family: continuous effort controller

The first candidate family uses nonlinear solver effort rather than the legacy binary `NUMBIT_CRIT` threshold.

After accepted step k:

`f = clamp(sqrt(I_target / max(I_k,1)), 0.5, 2.0)`

`dt_preferred(k+1) = dt_base * f`

where:

- `I_k` = nonlinear iterations on the accepted step;
- `dt_base` = previous preferred dt when available, otherwise executed accepted dt;
- rejected attempts never update `dt_base`;
- event clipping affects executed dt but not preferred memory;
- internal retry floor = 0.001 d in this discovery harness;
- no ordinary operating maximum timestep is used;
- the remaining simulation horizon is the hard event boundary.

Frozen iteration targets:

- I3 = 3;
- I4 = 4;
- I5 = 5;
- I6 = 6.

Frozen multiplicative limits:

- minimum factor = 0.5;
- maximum factor = 2.0.

Initial preferred dt:

- 0.005 d.

This is an internal bootstrap constant for the discovery harness, not a proposed user input.

## Failure recovery

On nonlinear failure:

- rollback to accepted origin;
- retry duration = max(retry_floor, attempted_dt / 2);
- retry does not alter accepted preferred-step memory;
- fail the case if retry at the floor still does not converge.

## Calibration bank

Use the already exposed 16 BOFEK01 screening cases.

Comparator:

current corrected LEGACY_NUMERICS trajectory.

P-C1 accuracy gates remain unchanged from BOFEK practical work:

- cumulative runoff: <=0.01 cm absolute when baseline <1 cm, otherwise <=1%;
- terminal storage: <=max(0.01 cm, 0.5% baseline storage);
- terminal ponding <=0.02 cm;
- top/mid/bottom pressure-head <=2 cm;
- max ledger <=5e-8 cm;
- no solver failure;
- retry pathology forbidden.

## Advancement

A target advances only if:

1. at least 15/16 cases pass P-C1;
2. every WET/POND case passes;
3. median deterministic work reduction >=15%;
4. no regime has median work regression >5%;
5. retry work fraction does not exceed LEGACY_NUMERICS by more than 5 percentage points.

Select highest median deterministic work reduction, tie-break lower target.

If no target advances, close effort-only AUTO_REFERENCE discovery and require a richer accepted-step/temporal signal.

If one advances, freeze it before constructing a new validation bank.

## Production boundary

No production controller activation and no parser change in TIMEARCH12 discovery.
