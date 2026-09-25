# F-PE-REF-TEMPORAL01 — Reference production temporal qualification

Date: 2026-09-25

Status: `PREREGISTERED`

## Purpose

This workstream qualifies a non-trivial production temporal acceptance route for Reference Richards.

It exists because APPQUAL01 established that:

- solver-level Reference/RossFast paired validity exists;
- large-N production Reference scaling exists;
- but a non-trivial paired production workload cannot be compared because the current Reference `FMR_NUMERICAL_CONTINUATION_NONE + EXTERNAL_FULL_HALF` route only accepts exact state identity.

This line does not add new soil-water physics and does not relax solver convergence criteria.

## Existing authority

The implementation already contains:

- `FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY`;
- Reference temporal-indicator evaluation;
- accepted-state derivative history;
- an explicit model temporal head budget;
- model-certificate transaction semantics.

FSI25 and FSI38 establish the indicator seam and noninterference.

F-CI14 explicitly states that the missing item is a qualified numerical temporal tolerance/profile. Candidate limits are not production authority.

## Research question

What temporal head-budget or application-qualified acceptance envelope can be independently justified for Reference Richards so that evolving production intervals can be accepted/retried without relying on bit-identical full/half endpoints?

## Constraints

1. No reuse of nonlinear convergence tolerances as temporal accuracy tolerances.
2. No tuning to make APPQUAL01/RossFast pass after observing the result.
3. Qualification values must be preregistered before evaluating the final benchmark.
4. Mass balance remains a separate hard gate.
5. Solver convergence route and physical equations remain unchanged.
6. Active optional process classes remain out of scope unless separately qualified.
7. The final budget must state its quantity, units, aggregation scale and provenance.

## Initial qualification domain

Start with the already-owned prescribed-qbot/reference-indicator domain:

- bottom mode 2;
- explicit top flux;
- no root extraction;
- no macropores;
- no snow;
- no drainage response;
- no soil temperature;
- no evaporation-memory process;
- B110/MvG hydraulics.

Use multiple:

- soils/materials;
- wet/mid/dry states;
- upward/downward/near-zero fluxes;
- interval durations;
- groundwater-relevant gradients.

## Reference oracle

For each trial interval, compare the production indicator prediction against a more resolved Reference trajectory.

Primary independent quantities:

- endpoint pressure-head error;
- endpoint water-content error;
- storage error;
- bottom exchange error;
- cumulative mass closure.

The production indicator must be tested for conservativeness and failure modes, not merely correlation.

## Qualification outputs

For each case persist:

- state and forcing identity;
- source commit;
- principal step duration;
- refined reference duration/substeps;
- indicator head bound;
- observed head error;
- bound/error ratio;
- mass residual;
- convergence/retry counts;
- classification.

Classifications:

- `BOUND_VALID_CONSERVATIVE`;
- `BOUND_VALID_NONCONSERVATIVE`;
- `INDICATOR_UNAVAILABLE`;
- `REFERENCE_ORACLE_INVALID`;
- `OUTSIDE_SCOPE`.

Negative cases are retained.

## Admission target

A production temporal budget may be admitted only if:

- the indicator is available on the target profile;
- the bound is sufficiently conservative over the preregistered qualification domain;
- a sensitivity analysis shows that the selected budget does not create unstable route switching;
- representative difficult columns are included;
- holdout cases are evaluated after the budget is frozen.

## APPQUAL01 dependency

APPQUAL01 may consume this line only after closeout.

Until then:

- APPQUAL01 B1 Reference scaling remains valid for its simple accepted workload;
- F-ROSS15 remains the Reference/RossFast solver-level comparison authority;
- no production-level RossFast speedup is claimed for a non-trivial transient workload.

## First work unit

`WU01 — indicator-vs-refined-reference calibration matrix`

No production admission change is permitted in WU01.
