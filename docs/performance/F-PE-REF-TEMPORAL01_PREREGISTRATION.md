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


## WU02 preregistration — expanded conservativity and sharpness matrix

Status: `PREREGISTERED_BEFORE_EXECUTION`

WU02 expands the WU01 domain before any temporal budget is selected.

### Purpose

Test whether the WU01 conservativity result persists in more difficult and less symmetric Reference Richards states, and quantify where the indicator is unnecessarily conservative.

### Fixed oracle

The oracle remains a refined Reference trajectory. WU02 will not switch oracle after results are observed.

For each principal interval:

- one principal Reference solve;
- one Reference temporal-indicator evaluation;
- one independently refined Reference trajectory over the same outer interval;
- endpoint comparison against the refined trajectory.

### Preregistered dimensions

At minimum include:

- wetter/near-saturated states than WU01;
- mid and dry states;
- nonuniform vertical head profiles;
- both upward and downward forcing;
- unbalanced top and bottom flux;
- stronger forcing than WU01;
- principal dt values larger than 1e-2 day and smaller than 1e-3 day where stable;
- multiple hydraulic parameter sets/materials;
- prescribed-qbot mode 2;
- prescribed-head mode 5 where the existing indicator envelope admits it.

### Required outputs

Per case:

- principal and refined solver validity;
- indicator availability and route;
- head-inf bound;
- endpoint head-inf error;
- bound/error ratio;
- endpoint theta-inf error;
- storage error;
- principal/refined mass residuals;
- principal nonlinear iterations;
- refined total nonlinear iterations;
- classification.

### Classification

Use exactly:

- `BOUND_VALID_CONSERVATIVE`;
- `BOUND_VALID_NONCONSERVATIVE`;
- `INDICATOR_UNAVAILABLE`;
- `PRINCIPAL_REFERENCE_INVALID`;
- `REFINED_REFERENCE_INVALID`;
- `OUTSIDE_SCOPE`.

No class may be dropped after seeing results.

### WU02 decision gates

WU02 is not a production-admission gate.

It may support later budget selection only if:

1. no unexplained nonconservative cases remain inside the claimed scope;
2. any nonconservative cases are reproduced and physically/numerically classified;
3. the lower tail of bound/error ratio is understood;
4. indicator sharpness is quantified separately from conservativeness;
5. a holdout set can still be reserved after any candidate budget is frozen.

No production temporal budget may be chosen during WU02.


## WU02B preregistration — lower-margin and mode-5 stress

Status: `PREREGISTERED_BEFORE_EXECUTION`

WU02B is targeted, not broad.

### Motivation

WU01 and WU02A produced no nonconservative valid cases. The smallest observed bound/error ratios were concentrated in nonuniform vertical-gradient cases with principal dt around 1e-2 day.

WU02B therefore targets the lower-margin regime and extends to the already-qualified prescribed-head temporal-indicator boundary envelope.

### Fixed scope

Include:

- nonuniform vertical pressure-head profiles only;
- wet/intermediate starting states;
- at least the default B110 and Hupsel hydraulic parameter sets;
- principal dt values centered on 1e-2 to 5e-2 day;
- stronger and asymmetric top forcing;
- mode 2 prescribed qbot;
- mode 5 prescribed bottom head;
- warm-started previous right derivative;
- refined Reference oracle over the same outer interval.

### Mode-5 authority

Mode 5 is in scope only because the existing Reference indicator explicitly supports bottom modes 2 and 5 and FSI25 provides a production-seam qualification for prescribed bottom head.

No new boundary semantics are introduced here.

### Oracle rule

Do not use a fixed refinement factor if it causes an invalid oracle.

WU02B uses convergence-by-refinement:

- start with 8 substeps;
- repeat with 16 and 32 substeps when valid;
- the finest two valid refinements must agree within a preregistered oracle-stability threshold before the case can classify indicator conservativeness;
- if stability cannot be established, classify `REFINED_REFERENCE_INVALID`.

The oracle stability threshold is:

- head-inf difference <= 1e-4 cm between the two finest valid refinements;
- theta-inf difference <= 1e-8;
- storage difference <= 1e-10 cm.

These values are oracle-convergence criteria, not candidate production temporal budgets.

### Required classifications

Exactly:

- `BOUND_VALID_CONSERVATIVE`;
- `BOUND_VALID_NONCONSERVATIVE`;
- `INDICATOR_UNAVAILABLE`;
- `PRINCIPAL_REFERENCE_INVALID`;
- `REFINED_REFERENCE_INVALID`;
- `OUTSIDE_SCOPE`.

### Decision rule

WU02B can support moving toward budget selection only if:

1. no valid in-scope case is nonconservative;
2. the minimum bound/error ratio is identified with a stable oracle;
3. mode-5 behavior does not create a new lower-margin regime;
4. the remaining invalid cases are bounded and explained.

No production temporal budget is selected in WU02B.
