# F-PE-TEMPORAL08 — production admission of frozen c=0.65 history-aware temporal budget

Date: 2026-09-26

Status: `PREREGISTERED_IMPLEMENTATION`

Parent:
- F-PE-ENDPOINT01 / PR #653
- parent head at workunit creation: `f565cfdcb14a771ac8c14a22479648013200f98d`

## Frozen policy

Production candidate:

`budget = max(1e-5 cm, 0.65 * dt * ||h_dot_previous||_inf)`

The coefficient 0.65 is frozen by TEMPORAL05.

No recalibration is permitted.

## Evidence entering admission

### TEMPORAL05
Blind physical qualification:
- 24/24 holdout points complete;
- mass complete;
- max |dh| = 6.565e-3 cm;
- max |dtheta| = 6.282e-6;
- max relative terminal flux error = 0.72%;
- max relative exchange error = 0.17%.

### TEMPORAL06
Production-shaped repeated corrector sequences:
- 768/768 complete;
- retries 384 for c=0.65 versus 768 for c=0.50;
- solver rejections 0;
- median runtime ratio c=0.65/c=0.50 = 0.73525.

### TANGENT01
The accepted-trajectory tangent is the correct derivative of the actual c=0.65 numerical response map:
- 8/8 same-policy directional matches;
- max relative mismatch approximately 2.8e-9.

### TEMPORAL07
- same-policy MODFLOW-facing linear response: PASS;
- production tangent cache: PASS;
- live one-SWAP/one-MODFLOW coupling converges;
- mass, MODFLOW component balance and publication invariants pass;
- the remaining independent endpoint failure was not c=0.65-specific.

### ENDPOINT01
The TEMPORAL07 endpoint blocker was diagnosed as extrapolation error in the historical three-probe q(H) oracle.
Direct q-space authority:
- c=0.50: PASS;
- c=0.65: PASS;
- historical canonical closeout preservation: PASS;
- physical residual and endpoint-head tolerances unchanged.

## Admission objective

Bind the frozen history-aware temporal budget into the production FMR groundwater participant route without moving temporal-history semantics into MODFLOW or the groundwater application context.

The production ownership boundary is:

`committed FMR numerical continuation state -> participant policy evaluation -> trial numerical config -> backend`

The MODFLOW/application layer must continue to see only:
- q;
- dq/dH;
- lineage;
- mass/publication state.

It must not receive or interpret h_dot history.

## Implementation design

Introduce an FMR-owned, optional temporal-budget policy carrier associated with a registered groundwater participant.

Minimum state:

- enabled;
- coefficient = 0.65;
- floor = 1e-5 cm.

Default:
- disabled.

When disabled:
- the participant passes the registered canonical numerical config through unchanged except for the existing accepted-trajectory tangent request.

When enabled:
1. snapshot the committed accepted FMR state;
2. require the temporal-indicator continuation state;
3. read the predecessor right derivative through its existing public accessor;
4. compute:
   `budget = max(floor, coefficient * dt * maxval(abs(previous_derivative)))`;
5. set only the trial-local `model_temporal_indicator_budget_available` and `model_temporal_indicator_budget`;
6. run the existing backend.

The registered base numerical config is not mutated.

## Fail-closed semantics

If the policy is enabled and any of the following is missing/invalid:
- temporal-history state type;
- predecessor derivative;
- derivative shape;
- finite derivative;
- finite positive coupling duration;
- finite positive coefficient/floor;

the trial fails closed before the backend solve.

No fallback to the fixed 1e-5 budget is permitted when the history-aware policy was explicitly enabled.

## P0 — unit and ownership qualification

Require:
- default-off bit/behavior preservation;
- enabled policy computes exact expected budget for seeded temporal histories;
- floor dominates when history magnitude is sufficiently small;
- coefficient branch dominates when history magnitude is larger;
- registered base numerical config remains unchanged;
- committed temporal history remains unchanged by rejected/discarded trials;
- missing history fails closed.

## P1 — production participant dynamic-origin qualification

Use the existing TEMPORAL07 difficult dynamic matrix.

Require:
- effective budget exactly equals frozen formula;
- completion and retry counts reproduce the research harness;
- zero solver rejections;
- same q, exchange and fresh tangent as the manually configured c=0.65 research authority;
- cache behavior unchanged.

## P2 — live MODFLOW6 fixed-interface qualification

Use the ENDPOINT01-qualified direct q-space endpoint authority.

Require unchanged:
- production coupled convergence;
- direct independent physical residual <= 1e-15 m/s;
- endpoint-head error <= 5e-10 m;
- MODFLOW model/API balance;
- stopping-flow gate;
- rejected-trial zero authority;
- publication order;
- exactly-once interface mass.

## P3 — default production preservation

With policy disabled:
- existing F-GC44/F-GC49D production fixtures retain current behavior;
- no historical fixed-interface numerical result is changed solely by introducing the carrier.

## Admission boundary

If P0-P3 pass:
- admit the policy mechanism as an opt-in production capability;
- enable c=0.65 only in the bounded fixed-interface groundwater profile qualified by this stack;
- preserve all other FMR users/default profiles unchanged.

If enabling at the existing generic registry bind would broaden behavior beyond the qualified profile, add an explicit bounded profile/bootstrap binding instead of changing the default.

## Scope exclusions

No change to:
- Richards equations;
- BALTOL02 balance floor;
- retry scale;
- tangent formulation;
- tangent-cache defaults;
- MODFLOW coupling equations;
- MODFLOW storage role;
- drainage/root-uptake admission;
- TEMPORAL04/05 physical error bounds;
- coefficient c=0.65.

Repository evidence decides admission.
