# F-PE-BOFEK01/02 preregistration — BOFEK-dependent numerical-policy screening

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority at preregistration:

`integration/f-ci-canonical@50ee9dc2acbc9847807d3fd98d0553f9862d428b`

BOFEK00 prerequisite:

`CANONICAL_ADMITTED`, fixed-K dynamic-top, `SWKIMPL=0`.

## Scope

This workunit measures whether solver/timestep effort can be reduced without reopening correctness. It separates:

1. correctness, frozen by BOFEK00 and current canonical;
2. numerical policy;
3. wall-clock/performance;
4. later practical-accuracy mode.

No `SWKIMPL=1` claim is permitted in this workunit without a separate preregistration.

## Reconciled parameter registry

Only controls proven active in current authority are eligible.

### Historical TimeControl policy

Source: `src/legacy/b1_10_fci11_port/timecontrol_part02/04/05.inc`.

Active controls:

- `DTMIN`;
- `DTMAX`;
- initial dt, defaulting to `sqrt(DTMIN*DTMAX)` when not supplied through the permitted initialization path;
- `NUMBIT_CRIT`;
- `MAXIT` as both solver cap and accepted-step shrink trigger in the historical controller;
- `fact_dt_increase`;
- `fact_dt_decrease`;
- `fact_dt_fldect`, the nonconvergence/failure reduction divisor;
- event clamps from end-of-day, output, meteorology, irrigation, runon and explicit interval boundaries.

The controller grows dt when `numbit <= NUMBIT_CRIT`, shrinks accepted dt when `numbit >= MAXIT`, and separately reduces dt on nonconvergence.

### Reference Richards solve controls

Current serialized Reference parameters include:

- `max_iterations`, default 8;
- `max_backtracking`, default 4;
- `min_step_duration`, default `1e-6 d` in the serialized backend type;
- compartment balance tolerance, configured default `1e-12`;
- total balance tolerance, configured default `1e-12`;
- head absolute tolerance, default `1e-12`;
- head relative tolerance, default `1e-12`;
- ponding tolerance, default `1e-12`.

BALTOL02 is already production authority and is not a free tuning knob: effective compartment and total balance-rate tolerances are

`max(configured_tolerance, 2.8e-16 cm / dt)`.

Practical A2C tolerances are outside the initial strict Reference screen.

### Existing negative/positive authority retained

- BOFEK00: wet Jacobian/runoff-branch correctness is fixed and is not retuned.
- SHORTSTEP01/BALTOL01/BALTOL02: short-step failures were caused by an over-strict absolute balance floor; the dt-scaled floor is admitted and remains fixed during initial screening.
- TEMPORAL08: c=0.65 history-aware temporal budget is production-admitted only for its bounded groundwater profile. It is not generalized here.
- BASE01: broad exact single-column micro-optimization is closed; BOFEK01/02 targets less solve/timestep work instead.

## Test-bank design

Initial development bank will contain 20 cases, split 16 calibration/screening and 4 untouched holdouts.

Profiles are stratified by hydraulic behavior, not selected randomly. The bank must include:

- fast/high-K sand;
- medium sand;
- low-K fine sand;
- loam/silt-like response;
- clayey/low-K response;
- strong capillary response;
- sharp retention;
- gradual retention;
- known difficult near-saturation cases.

Each profile is exercised in at least two materially distinct regimes selected from:

- dry/deep groundwater;
- dry-to-wet transition;
- sustained wet;
- heavy-rain/ponding;
- shallow groundwater;
- drainage-active;
- infiltration-dominated.

The wet/ponding subset must exercise the BOFEK00 dynamic-top route.

Until a repository-owned full BOFEK parameter catalogue is available, only repository-backed hydraulic parameter sets may be used for qualification. Synthetic interpolation between profiles is allowed for harness development but cannot support a BOFEK-class production claim.

## Strict Reference baseline

For every case record:

- wall-clock, with repeated paired runs where timing is used;
- attempts, accepted steps and rejections;
- retry count;
- accepted-dt sequence and min/median/max;
- growth and shrink events;
- nonlinear iterations;
- iterations per accepted step;
- backtracking attempts;
- Jacobian builds;
- linear solves;
- temporal and solver rejection counts where exposed;
- runoff, drainage, bottom flux and ponding;
- terminal state;
- cumulative water balance and maximum ledger residual.

A difficulty fingerprint is the vector of normalized work metrics:
`[accepted steps, rejects, nonlinear/step, backtracks/step, fraction at DTMIN, fraction near DTMAX]`,
augmented by hydraulic/regime descriptors.

## Screening sequence

Screen parameter families separately before interactions.

### A. Timestep envelope

Frozen candidate values:

- `DTMAX`: `0.5x, 1x, 2x, 4x` baseline, capped by physical/event boundaries;
- `DTMIN`: `0.25x, 0.5x, 1x, 2x` baseline;
- initial dt: `DTMIN`, geometric mean, `0.5*DTMAX`, `DTMAX`.

Advance a parameter only if median solver-work reduction is at least 8% over screening cases and no strict gate fails.

### B. Timestep adaptation

Frozen candidate values:

- `NUMBIT_CRIT`: `2, 3, 4, 5, 6`;
- increase factor: `1.25, 1.5, 2.0, 3.0`;
- accepted-step decrease factor: `0.25, 0.5, 0.75`;
- failure reduction divisor: `1.5, 2.0, 3.0, 4.0`.

Advance only candidates with at least 8% median solver-work reduction and no increase larger than 25% in the 90th-percentile rejected-attempt count.

### C. Nonlinear solve effort

Frozen candidate values:

- `MAXIT`: `5, 6, 8, 10, 12`;
- `max_backtracking`: `2, 4, 6, 8`;
- head abs/rel tolerance multiplier relative to strict baseline: `1, 10, 100`;
- ponding tolerance multiplier: `1, 10, 100`.

Balance tolerance is not screened here because BALTOL02 already owns its strict numerical floor.

Tolerance multipliers greater than 1 are research-only until they pass the strict physical gates below.

## Strict physical gates

For each candidate, compare against that case's strict baseline.

All strict gates must pass:

- cumulative water-ledger absolute residual <= `5e-8 cm` per accepted step and no material worsening of cumulative ledger;
- cumulative runoff absolute difference <= `1e-4 cm` OR relative difference <= `0.1%`, whichever is less permissive once the reference magnitude exceeds `0.1 cm`;
- cumulative drainage difference <= `1e-4 cm` OR `0.1%` under the same rule;
- cumulative bottom-flux difference <= `1e-4 cm` OR `0.1%`;
- terminal ponding difference <= `1e-4 cm`;
- maximum terminal pressure-head difference <= `1e-3 cm`;
- no new solver failure;
- no new retry pathology, defined as >2x reference retries or >25% of attempts rejected.

A candidate that fails any strict gate cannot support `QUALIFIED_*_NUMERICAL_POLICY`.

## Performance metric

Primary screening metric is deterministic solver work, not noisy wall-clock:

`work_index = nonlinear_iterations + backtracking_attempts + jacobian_builds + linear_solves`.

Secondary metrics are accepted-step count, attempts and paired wall-clock.

A performance claim requires wall-clock confirmation on the shortlisted policies. At least five paired repetitions per case are required for final timing. Median paired ratio is reported.

## Interaction stage

Only parameters that independently pass screening may enter interactions.

Planned first interactions:

- `DTMAX x NUMBIT_CRIT`;
- `DTMIN x head tolerance` only if head tolerance advanced;
- `MAXIT x failure reduction divisor`;
- hydraulic class x `DTMAX`;
- wetness regime x adaptation aggressiveness.

No post-hoc expansion of ranges is allowed without an amendment committed before the new results are generated.

## Policy selection rule

Prefer the least complex policy whose holdout performance is statistically and operationally distinguishable.

Candidate outcomes:

1. global policy, if one parameter set is within 5 percentage points of the best median work reduction in every represented hydraulic/regime class;
2. BOFEK/hydraulic-class policy, if class-specific policies improve median work by at least 10 percentage points over the best global policy in at least two classes without worse strict accuracy;
3. regime-aware policy, only if regime split adds at least 10 percentage points over class-only policy on holdout;
4. no policy change if these thresholds are not met.

## Holdout

Four cases are frozen before screening and excluded from selection. Final qualification requires:

- strict gates on all holdouts;
- no wet BOFEK00 regression;
- no dry-case failure;
- median paired runtime improvement >= 10%;
- no individual holdout runtime regression > 10% unless it is within timing noise and solver-work is non-inferior.

## Practical mode

Practical/coupling tolerances may be explored only after strict screening and holdout are closed. Such results can end only as `PRACTICAL_MODE_CANDIDATE_RESEARCH_ONLY` unless separately admitted.

## Production-write gate

No production numerical default or policy mapping may change before:

1. current-canonical preservation;
2. repository-backed BOFEK test bank;
3. strict baseline;
4. preregistered screening;
5. shortlist;
6. holdout;
7. BOFEK00 wet-regime preservation.

