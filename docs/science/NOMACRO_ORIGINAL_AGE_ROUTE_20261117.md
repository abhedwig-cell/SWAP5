# Original no-macro water-age route

**Bounded work-unit qualification; canonical admission is recorded separately.**
Historical closure remains PARTIAL, whole scientific equivalence NOT_QUALIFIED,
and the named RC2 release scope unchanged. Previous chemical/aquifer source and
state chains remain immutable.

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

Small real provider drivers, the existing150-step literal oracle, corrected
original-host observations, explicit soil/pond/source ledgers and real native
ownership are exercised. The age interval applies the original dtmin floor
before capping by the remaining accepted water interval; it cannot overshoot
that interval. This numerical clock policy is separate from SWSOLU=2 and the
physical input selectors. Age balance retains the existing8192*epsilon*inventory
policy in cm day. Chemical1e-10mg/cm2 and water1e-10cm guards remain unchanged.

## Corrected effluent output

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

No-export means are the explicit missing sentinel -9999, with zero water and
age amount. The companion `ageeffluentwater.csv` supplies actual cm exported for
every mean-age column. `ageeffluentqdrain.csv` reports positive drainage exports
in cm over that same interval. The native AGE002 owner includes these output
amount/volume counters. Required gates include weighted-mixture/duration/unit
counterexamples, native output fidelity, and exact preservation of every prior
core trajectory. The supported Linux joint-owner preservation is inherited only
after literal input-closure and compiler checks. It is not presented as a fresh
execution for the independent new observer/output changes.

## Executed scope and limits

- Windows and Ubuntu, initial ages0/100days, donor/kernel O0/O2: eight full1096day
  trajectories,32 full native windows, eight short native windows, all four age
  CSV files and actual root/runoff/drain exports. The original34node Hupsel
  input uses daily output, no macro, aquifer, fixed irrigation, snow or salinity.
- All8768 daily core rows and age-profile rows remain exact to the pre-output
  stage. Seventy-two native comparisons preserve every prior core byte after
  projecting out only the sixteen declared new output doubles and codec tag.
  Old checkpoints are compared read-only; none is converted or rebound. Actual
  new-code restarts use AGE002 and reproduce the complete new native payload.
- Both platforms exercise active pond ageing/infiltration at day367, external
  adoption, discard/replay, disk recovery, independent origins and deliberate
  corrupt candidate refusal before acceptance. Windows additionally runs eight
  original-reader refusals and forty private-native refusals, including AGE001
  rejection and output-volume/amount corruption.
- Eleven fresh age-off fixed/scheduled chemical, water, named-three, pulse and
  aquifer contexts preserve emitted/provider/flag/input closures and exact
  physical/CSV/native prefixes. Unchanged full periods are not repeated.
- The public run/build-bundle/restart CLI is exercised with exact physical,
  age-ledger and all-five-CSV windows. Qualification data and raw inventories
  are under `integration/f-ci/nomacro-complete01/AGE_*`; admission is separate.

Reference differences remain explicit: the original printed age profiles differ
from the corrected original-host profiles by up to0.1day and from the SWAP5 host
by up to2.75days. Original profile output has only four significant digits.
These composite differences have no fitted acceptance tolerance or individually
established cause. Tracer retention under evaporation is inherited policy, not
an independent validation of physical mean-water age. Conservation, functional
execution and restart do not establish whole-model equivalence.

Fixed-irrigation age coupling, non-daily output continuation, vapor and other
historical compositions remain separate inventory work. Generic experimental
input acceptance is not qualification of every allowed option combination.
The earlier direct age `--source-only` dispatch error was reproduced on actual
canonicaledbc before new code; registered current-source hooks must preserve its
literal historical assertions while binding current qualification. The older
POSIX snapshot route's Windows fsync link failure is retained, not relabelled
PASS; its supported Linux physical/native owner is qualified and preserved.

```text
python -B tools/solute/run_water.py --model HYBRID_NOMACRO_WATER --experimental-project INPUT --reference-work PROVIDER --build-only --output BUILD
python -B tools/solute/run_water.py --model HYBRID_NOMACRO_WATER --experimental-project INPUT --reference-work PROVIDER --build-bundle BUILD --days 5 --checkpoint-at 2 --output RUN
python -B tools/solute/run_water.py --model HYBRID_NOMACRO_WATER --experimental-project INPUT --reference-work PROVIDER --build-bundle BUILD --days 4 --restart RUN/accepted-column-1-day-2.zip --restart-day 2 --output COLD
```
