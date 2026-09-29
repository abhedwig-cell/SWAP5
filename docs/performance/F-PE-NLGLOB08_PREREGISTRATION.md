# F-PE-NLGLOB08 preregistration — post-stationarity physical tail-drift attribution

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@a82721f5ebece9376f83ab9b0fe5df26e42a36f2`

Parent authority:

- TIMEINT17: `BLOCKED_TG_DYNAMIC_TOP_BY_ENDPOINT_GLOBALIZATION`;
- NLGLOB04: `NLGLOB04_STORAGE_REPRESENTATION_FLOOR_SIGNAL`;
- NLGLOB07: `NLGLOB07_STATE_STATIONARITY_NONSPECIFIC`.

## Purpose

NLGLOB07 showed that representational moisture-state stationarity is universal at terminal failure but also occurs materially earlier.

NLGLOB08 asks whether those early S0 occurrences are actually unsafe, or merely temporally early while the accepted physical moisture state has already become inert.

The frozen question is:

**after an S0-certified point, does any later accepted Newton origin change the physical moisture state by more than the unchanged accepted water-depth significance scale?**

P0 is observational only.

## Frozen bank

Reuse the unchanged NLGLOB07 bank and S0 definition:

- 4 materials;
- 3 routes;
- TG and KLAG;
- 4 dt levels;
- 96 endpoint-failure trajectories;
- unchanged dynamic-top provider;
- unchanged K staging;
- unchanged BALTOL02;
- unchanged head and ponding contracts.

The 32-ULP S0 rule is inherited unchanged and is not reopened.

## Tail-drift measures

For every S0-certified evaluation point k in a trajectory and every later accepted Newton origin j > k define:

`DeltaS_L1(k,j) = sum_i dz_i f_i |theta_i^j-theta_i^k|`.

Define:

`TAIL_MAX(k) = max_(j>k) DeltaS_L1(k,j)`.

Define terminal drift:

`TAIL_FINAL(k) = DeltaS_L1(k,k_terminal)`.

No signed cancellation is allowed in these measures.

They quantify physical moisture-state movement in cm water depth.

## Frozen physical-inertness threshold

A certified point is `TAIL_INERT` iff:

- `TAIL_MAX <= 5e-8 cm`;
- `TAIL_FINAL <= 5e-8 cm`;
- all later states are finite;
- provider route remains equal to the frozen fixture route.

The `5e-8 cm` threshold is inherited from the existing physical accepted-interval mass gate. It is not tuned from NLGLOB07 outcomes and is not a new solver tolerance.

## Populations

### P1 — all S0-certified points

All NLGLOB07 S0-positive evaluation points.

### P2 — early S0 points

S0-positive points ending strictly earlier than the final two Newton iterations.

These were treated as false positives by NLGLOB07 and are the decisive population here.

### P3 — terminal S0 points

Final-iteration S0 points.

Expected to have zero tail by definition and used only as a consistency control.

## Negative/comparator populations

### C1 — non-S0 early points with later meaningful motion

Early eligible points that are not S0-certified.

Record the fraction with `TAIL_MAX > 5e-8 cm`.

This is not a hard safety gate; it tests whether the tail metric distinguishes continuing physical evolution.

### C2 — route/nonfinite pathology

Any point whose later tail contains route mismatch or nonfinite state.

Must never classify TAIL_INERT.

## Frozen qualification gates

Classify:

`NLGLOB08_POST_STATIONARITY_TAIL_PHYSICALLY_INERT`

only if all hold:

1. complete 96-case bank and NLGLOB07-equivalent diagnostic coverage;
2. at least 100 S0-certified points are available;
3. at least 50 early S0 points are available;
4. >=95% of all S0-certified points are TAIL_INERT;
5. >=95% of early S0 points are TAIL_INERT;
6. the early-inert direction is represented in TG and KLAG, all 3 routes and at least 3 materials;
7. C2 route/nonfinite pathological points have inert false-positive rate 0;
8. median and 95th-percentile `TAIL_MAX` for early S0 points are reported;
9. no physical flux is reconstructed from storage and no solver behavior is changed.

If early S0 inert fraction <50%:

`NLGLOB08_EARLY_STATIONARITY_HAS_MEANINGFUL_TAIL_DRIFT`.

If C2 fails:

`NLGLOB08_TAIL_INERTNESS_UNSAFE`.

If coverage fails:

`BLOCKED_NLGLOB08_TAIL_DRIFT_COVERAGE`.

Otherwise:

`NLGLOB08_MIXED_TAIL_DRIFT_SIGNAL`.

## Positive consequence

A positive result would establish that NLGLOB07's early S0 triggers are temporally early but physically inert within the existing water-depth authority.

That would invalidate iteration position as a safety negative control for this specific bank.

It would authorize a separately preregistered test-only replay workunit that terminates on the unchanged S0 rule and then requires:

- unchanged physical accepted-interval mass closure;
- unchanged cumulative mass closure;
- finite route-consistent state;
- existing head/ponding guards;
- comparison against the later canonical endpoint trajectory.

A positive P0 still does not change production convergence.

## Stop rule

Do not change after result exposure:

- S0;
- the 5e-8 cm tail threshold;
- P1/P2 definitions;
- route/finite guards.

A negative result closes this tail-inertness hypothesis.

## Architecture invariants

Affected invariants: 7, 13, 23, 24, 25, 26, 30.

Expected P0 effect: observational only.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB08

BASELINE: `a82721f5ebece9376f83ab9b0fe5df26e42a36f2`

BRANCH: `research/f-pe-nlglob08-tail-drift`

SCOPE: observational post-stationarity physical tail drift

INTERFACES CHANGED: none

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: implement deterministic tail-drift analysis on the frozen bank

RECOVERY POINT: this preregistration commit

DEPENDENCIES / BLOCKERS: endpoint replay blocked until tail inertness qualifies

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
