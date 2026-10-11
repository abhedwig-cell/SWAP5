# F-PE-STATESTEP01 preregistration — history-aware accepted-step controller

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority: `integration/f-ci-canonical@0714438bbb248e8056b0ad096dc02ceae8e48e22`.

## Purpose

Test whether a causal state-aware timestep controller can recover the large-step gains seen in BOFEK practical screening without static soil/regime lookup tables.

No production source change is permitted in this workunit.

## Scope

Fixed-K dynamic-top, SWKIMPL=0, corrected BOFEK00 route.

The existing production temporal indicator is not reused because its admitted envelope requires an explicit fixed-flux top boundary. This workunit instead uses accepted-step information already available on the dynamic-top path.

## Controller

After every accepted step compute:

`dh_inf = max_i |h_i(t1)-h_i(t0)|`.

For target `H`:

`factor = clamp(sqrt(H / max(dh_inf, 1e-12 cm)), 0.5, 2.0)`

`dt_next = clamp(dt * factor, DTMIN, 4*DTMAX_reference)`.

First step uses the current Reference geometric initial dt.

Failure reduction remains the Reference factor 2.

Two families are frozen:

- H_ONLY: use the rule above.
- H_SURF: same rule, but if accepted ponding > 0 or accepted runoff depth > 0, cap `dt_next <= DTMAX_reference`.

Targets screened independently:

- 0.25 cm
- 0.5 cm
- 1.0 cm
- 2.0 cm
- 4.0 cm

## Calibration bank

Reuse the already exposed 16 BOFEK01 screening cases only for coefficient selection.

Accuracy class is P-C1 from BOFEK practical work:

- runoff difference <=0.01 cm when Reference runoff <1 cm, otherwise <=1%;
- terminal storage <=max(0.01 cm, 0.5% Reference terminal storage);
- terminal ponding <=0.02 cm;
- top/mid/bottom head <=2 cm;
- max ledger <=5e-8 cm;
- no solver failure or retry pathology.

A coefficient is calibration-feasible only if at least 15/16 pass and every WET/POND case passes.

Among feasible coefficients/families choose:
1. highest median deterministic work reduction;
2. tie-break lower target H;
3. tie-break H_SURF over H_ONLY.

Advance only if median deterministic work reduction >=15%.

The selected controller is frozen before new validation cases are created or exposed.

## Validation

If a candidate advances, create a separately committed new 16-case validation bank before running it. Final research qualification requires:

- >=15/16 P-C1 pass;
- all wet/ponding pass;
- median work reduction >=15%;
- no regime median work regression.

Final status can only be `PRACTICAL_MODE_CANDIDATE_RESEARCH_ONLY` or `CLOSED_NO_STATE_AWARE_GAIN` in this workunit.
