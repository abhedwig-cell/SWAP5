# Original no-macro water-age route

**In development; not qualified or canonically admitted.** Historical closure
remains PARTIAL and whole scientific equivalence NOT_QUALIFIED. The admitted
chemical/aquifer source and state chains remain immutable.

The original SWSOLU=2 branch is distinct from chemical mass. Age concentration
is days and its amount is water depth times days. Actual bounds-checked original
O0/O2 runs with initial ages0/100days complete1096days with finite original age
profiles/effluent. This does not yet establish a complete age balance or restart.

Reuse `mod_b111_age_tracer_substep` and the already admitted surface-age provider;
do not duplicate their equations. The existing small process/literal-oracle
driver passes before changes. Two opt-in adapter requirements are necessary for
the original host's internal solute clock:

1. Original age production uses the midpoint of the accepted water step's theta
   endpoints for every age microstep. The water content used to reconstruct
   concentration advances to the end-water content after the first microstep.
   These are different responsibilities. An optional `production_theta_mean`
   vector supplies the former without changing the default existing provider.
2. Original age, like the admitted pond-age budget, retains the age tracer on
   evaporation. The existing accepted surface handoff excludes positive top
   flux. An explicit `evaporative_top_retains_age` option allows that original
   boundary only with a nonnegative actual top water flux and exactly zero
   external age handoff. Existing negative-handoff and default exclusions remain.

These options preserve the existing equations and make the original clock and
boundary policies explicit. They do not assert that retained age tracer is an
independently validated physical mean-water-age law under evaporation. The
original and accepted age contracts are the bounded reference authorities.

The original top water flux may be upward during soil evaporation. The surface
water balance must retain that actual return flow separately from external
runon. Add zero-default `soil_return_depth_cm` and `soil_return_age_day` to the
existing surface request, with a separate internal age-input receipt. Original
tracer retention supplies zero upward age despite positive upward water; this
is explicit policy, not missing water or an invented external source. Existing
surface callers keep their zero-default arithmetic and existing acceptance
criteria. The new small driver checks returned water, age units, production,
separate internal attribution and invalid domains.

Before generic input activation, require a small real provider driver, preservation
of the existing150-step literal-oracle tests, actual corrected/source reference
observations, explicit soil/pond/source/effluent ledgers, accepted-state/native
ownership and ordinary/active/year restart. Age balance uses its separately named
accepted age units and policy; the existing chemical1e-10mg/cm2 and water1e-10cm
guards remain unchanged. Original unsupported snow/macro combinations must stay
refused. Surface and microstep adapters remain implementation work, not evidence
of functional admission.

## Effluent output correction in development

The first core stage passed Windows/Ubuntu full source/state/native tests and
existing-owner preservation, persisted in `AGE_CORE_QUALIFICATION.json` at
`integration/f-ci/nomacro-complete01`. It is not canonically admitted. Original
effluent output divided an accumulated age amount (cm day) by output time
(day), producing cm while labelling the result days. Its drainage-water file
also labelled accumulated cm as mm/day. These are inherited output defects.

The independent production `mod_age_effluent_observer` computes positive
exported water and the corresponding age amount separately for bottom, roots
and each drainage level. Mean effluent age is their ratio, in days. Negative
drainage is inflow, not exported water in the denominator. Runoff uses the
already accepted pond-age export. The adapter checks observed age exports
against the actual transport receipt before accumulating them over the same
output interval; it does not change transport or accepted core age state.

No-export means are the explicit missing sentinel -9999.9, with zero water and
age amount. The companion `ageEffluentWater.csv` supplies actual cm exported for
every mean-age column. `ageEffluentqDrain.csv` reports positive drainage exports
in cm over that same interval. The native AGE002 owner includes these output
amount/volume counters. Required gates include weighted-mixture/duration/unit
counterexamples, native output fidelity, and exact preservation of every prior
core trajectory. Earlier supported Linux joint-owner preservation is inherited
only after literal input-closure validation; no repeat is selected for an
independent new observer or an output-only host change.
