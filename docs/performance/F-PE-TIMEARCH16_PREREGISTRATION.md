# F-PE-TIMEARCH16 preregistration — wet-zone AUTO eligibility guard

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@284f658d7b19efde1da728e3521a40186221eb05`

Parent authority:

- TIMEARCH15: flux-regime AUTO -> LEGACY_SAFE state machine reached 15/16 P-C1 and about 34.3% median deterministic work reduction on passing cases;
- sole blocker: B01/POND solver-floor failure during AUTO recovery;
- REFINE4 and REFINE8 were identical, so transition-refinement depth is not the remaining lever.

## Purpose

Test whether AUTO_REFERENCE can be restricted to a physically dry-enough accepted surface state, while retaining the TIMEARCH15 state-machine structure.

This is a state-based eligibility rule, not a material/regime lookup and not a normal operating DTMAX.

## Base controller

Unchanged from TIMEARCH15:

- AUTO proposal uses normalized accepted-state pressure-head movement with target R=0.40;
- no normal operating DTMAX in AUTO;
- internal bootstrap = 0.005 d;
- retry floor = 0.001 d;
- dynamic-top endpoint mode FLUX required for AUTO;
- leaving FLUX triggers REFINE4 transition handling;
- after HEAD/runoff transition, enter LEGACY_SAFE permanently;
- AUTO nonlinear failure immediately enters LEGACY_SAFE.

## New AUTO eligibility guard

After each accepted AUTO endpoint, before proposing the next AUTO step:

if:

`h_top > H_guard`

then:

- AUTO is disabled;
- enter LEGACY_SAFE permanently for the remainder of the calibration case;
- next preferred dt is computed by the current legacy accepted-step proposal from the just-executed accepted dt.

Frozen thresholds:

- GUARD_M20: H_guard = -20 cm;
- GUARD_M10: H_guard = -10 cm;
- GUARD_M5: H_guard = -5 cm.

If endpoint mode is already HEAD or runoff, the existing TIMEARCH15 fallback rule applies regardless of threshold.

## Calibration bank

Use the already exposed 16 BOFEK01 screening cases.

Comparator:

LEGACY_NUMERICS current corrected Reference route.

P-C1 gates remain unchanged.

## Advancement

Candidate advances only if:

1. 16/16 cases pass P-C1;
2. every WET/POND case passes;
3. median total deterministic work reduction >=15%;
4. no hydrologic regime has median work regression >5%;
5. retry-work fraction is no more than 5 percentage points above LEGACY_NUMERICS;
6. no material/regime identifiers enter the controller.

The requirement is raised to 16/16 because TIMEARCH15 already reached 15/16 and this workunit is explicitly designed to repair that single blocker.

Selection:

- highest median deterministic work reduction;
- tie-break the less conservative threshold: -5, then -10, then -20 cm.

If no candidate advances, close the wet-zone guard family.

If one advances, freeze it before constructing a new validation bank.

## Production boundary

No production AUTO_REFERENCE activation, parser change or default-profile change in TIMEARCH16.
