# F-PE-TIMEARCH15 preregistration — flux-regime AUTO with conservative fallback

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@9ab4042ee7e70eb8fd9679e1e408250f61190266`

Parent authority:

- TIMEARCH01-11: timestep architecture and AUTO_REFERENCE interface qualified;
- TIMEARCH12: effort-only AUTO rejected;
- TIMEARCH13: pre-solve dynamic-top risk prediction rejected;
- TIMEARCH14: trial-detected mode transition refinement retained ~34% work signal on passing cases but was not robust enough;
- SHORTSTEP/TEMPORAL authority: smaller dt is not monotonically easier for the nonlinear solver.

## Purpose

Test a conservative AUTO_REFERENCE state machine rather than one universal adaptive rule.

The design explicitly separates a fast operating region from a safe fallback region.

## Controller states

### AUTO_FLUX

Active only while the accepted dynamic-top endpoint remains FLUX.

Proposal:

`r_h = max_i(|h_i(k)-h_i(k-1)| / max(10 cm, |h_i(k-1)|))`

with frozen target `R=0.40`.

`f = clamp(sqrt(R/max(r_h,1e-12)),0.5,2.0)`

`dt_next = preferred_dt * f`.

No normal operating DTMAX.

Internal bootstrap = 0.005 d.

### LEGACY_SAFE

Once entered, use the current legacy accepted-step proposal with:

- current Reference DTMAX = 0.02 d;
- current retry floor = 0.001 d;
- current NUMBIT_CRIT / MAXIT / growth / decrease factors.

This is an explicit conservative fallback, not the normal automatic selector.

Once entered, LEGACY_SAFE remains active for the rest of the short calibration case.

## State transitions

### Initial accepted endpoint

- if endpoint mode is FLUX: remain AUTO_FLUX;
- if endpoint mode is HEAD_NO_RUNOFF or HEAD_RUNOFF: enter LEGACY_SAFE.

### AUTO candidate stays FLUX

Commit the full candidate and remain AUTO_FLUX.

### AUTO candidate leaves FLUX

Do not commit the full candidate.

Refine the same outer interval using equal substeps from the same accepted origin.

Two frozen refinement depths:

- REFINE4: 4 substeps;
- REFINE8: 8 substeps.

If all refinement substeps solve and pass ledger:

- commit the final refined endpoint;
- enter LEGACY_SAFE.

The discarded full-candidate work and all refinement work count toward performance.

### AUTO nonlinear failure

Do not continue the AUTO shrink loop.

Enter LEGACY_SAFE immediately and retry from the same accepted origin using:

`min(Reference DTMAX, max(retry_floor, attempted_dt/2))`.

### LEGACY_SAFE failure

Use current legacy failure reduction semantics.

## Surface mode

Endpoint mode:

- FLUX;
- HEAD_NO_RUNOFF;
- HEAD_RUNOFF.

No soil/material/regime identifiers are used.

## Calibration bank

Use the already exposed 16 BOFEK01 screening cases.

Comparator:

LEGACY_NUMERICS on current corrected Reference route.

P-C1 gates remain unchanged.

## Advancement

Candidate advances only if:

1. >=15/16 P-C1 pass;
2. all WET/POND cases pass;
3. median total deterministic work reduction >=15%;
4. no hydrologic regime has median work regression >5%;
5. retry-work fraction is no more than 5 percentage points above LEGACY_NUMERICS;
6. all refined transition substeps satisfy the unchanged ledger gate.

Selection:

- higher median work reduction;
- tie-break REFINE4 over REFINE8.

If neither advances, close the flux-AUTO/fallback family.

If one advances, freeze it before creating any new validation bank.

## Production boundary

No production controller activation, parser change or default-profile change in TIMEARCH15.
