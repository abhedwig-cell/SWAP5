# NUM-UNC P0A parameter-authority resolution

Date: 2026-09-19
Decision: ADMISSIBLE_FOR_P0_PILOT_PARAMETER_BINDING
Scope: Feddes drought parameters only
Production/reference source mutation: none

## Question

P0A was blocked because the current canonical source tree did not contain a provenance-complete active-crop profile for hlim3h, hlim3l, hlim4, adcrh and adcrl. Inventing defaults was explicitly forbidden.

## Recovered historical qualification authority

The SWAP5 project Library contains the earlier A14 root-water-uptake qualification package for the 2002 Hupsel simple-maize route.

README_A14.md identifies the scope as the macroscopic Feddes route used by the 2002 Hupsel simple-maize crop and states that SWAP 4.3.1 was instrumented to record the real legacy root-uptake inputs and outputs over that crop period.

The recorded real-state oracle contains 3,403 root-uptake evaluations and 75,972 node rows, with actual Hupsel potential transpiration, Feddes thresholds and Jarvis settings. It reports zero maximum difference in qpotrot, qrot, total uptake and computed hlim3.

The same qualification additionally used three deliberately stressed legacy states and reports differences only at floating-point roundoff scale. A full three-year substitution gate replaced the legacy 2002 maize root-uptake call by A14 and retained identical normalized result.bal, result.blc, swap.wrn, swap.ok and swap.log outputs.

mod_a14_root_water_uptake.f90 binds the qualified Hupsel configuration as:

- hlim3h = -325 cm;
- hlim3l = -600 cm;
- hlim4 = -8000 cm;
- adcrh = 0.5 cm/day;
- adcrl = 0.1 cm/day.

The later A22 crop-state boundary independently contains the same five literals. More importantly, its legacy adapter captures those five quantities from the live legacy crop modules and its season-wide shadow reports 3,403 valid maize snapshots, zero crop-configuration changes and maximum configuration delta zero.

## Limitation

The historical A14/A22 package zip cannot be raw-byte materialized in the current tool runtime. Therefore this resolution relies on the parsed, separately stored project artifacts and their persisted qualification summaries rather than a new byte-level replay of the historical package.

This is sufficient for a P0 research pilot because the parameter values are no longer invented, their crop/model provenance is identified, the scientific process was previously compared against actual legacy states and stressed legacy states, and the current P0 harness will execute the current canonical root-uptake process and Reference Richards route rather than the historical A14 executable.

It is not sufficient to claim that the historical A14 package has been independently requalified today.

## P0 binding decision

P0A may use the five values above as the historical Hupsel simple-maize drought parameter set.

P0A does not import the full A14 crop model, oxygen stress, Jarvis compensation, crop development or dynamic root development. Those are outside the P0 mechanism.

The controlled P0 root distribution and forcing are separately preregistered and must not be described as a reproduction of the Hupsel field case.

## Potential-transpiration anchor

The recovered A22 integrated four-step trace on 10 June 2002 reports the same potential transpiration on all four accepted steps: 0.1806735915459957 cm/day.

P0A uses this value as a provenance-anchored forcing magnitude. It does not claim that the rest of the controlled P0 experiment reproduces 10 June 2002.

## Claim boundary

This authority resolution establishes input provenance for the P0 pilot. It does not itself establish NUM-UNC novelty, numerical amplification, crop representativeness or generality across crop types.
