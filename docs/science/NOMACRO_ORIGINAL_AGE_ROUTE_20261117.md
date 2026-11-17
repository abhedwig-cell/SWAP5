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

Before generic input activation, require a small real provider driver, preservation
of the existing150-step literal-oracle tests, actual corrected/source reference
observations, explicit soil/pond/source/effluent ledgers, accepted-state/native
ownership and ordinary/active/year restart. Age balance uses its separately named
accepted age units and policy; the existing chemical1e-10mg/cm2 and water1e-10cm
guards remain unchanged. Original unsupported snow/macro combinations must stay
refused. Surface and microstep adapters remain implementation work, not evidence
of functional admission.
