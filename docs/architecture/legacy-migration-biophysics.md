# Crop, uptake, stress, solute and WOFOST-soil

**Part of:** [Legacy-to-target migration map](legacy-migration.md)  
**Baseline:** SWAP 4.3.1

| Legacy file | Migration action | Target destination(s) | Migration intent |
| --- | --- | --- | --- |
| `MOD_cropdevelopment.f90` | `SPLIT_RETAIN_PHYSICS` | Crop/ET physics; Runtime/event scheduling; Adapters | Crop-development physics stays in kernel component; rotation/event orchestration and input concerns become explicit runtime/forcing events. |
| `RWU_micro.f90` | `SPLIT_RETAIN_OPTIONAL_PHYSICS` | Crop/ET/root-uptake optional physics; Adapters | Retain model where active; move input reading out and expose explicit parameters/state/scratch. |
| `fixed.f90` | `SPLIT_RETAIN_PHYSICS` | Crop/ET physics; Adapters | Keep fixed-crop behaviour as a crop implementation; move reading and global coupling outward. |
| `interface_atmosphere.f90` | `REPLACE_INTERFACE` | Surface/atmosphere typed interface; forcing/results | Replace global exchange variables with typed forcing and process result contracts. |
| `interface_plant.f90` | `REPLACE_INTERFACE` | Crop/ET typed interface; committed crop state; shared parameters | Use semantics as migration inventory, not as final global module. Replace mutable shared arrays with typed contracts. |
| `oxygenstress.f90` | `DECOMPOSE_OPTIONAL_PHYSICS` | Crop/ET/root-stress physics; worker/process scratch | Preserve qualified stress physics, but isolate expensive numerical integrations/intermediates from persistent state and avoid redundant calls. |
| `rootextraction.f90` | `RETAIN_PHYSICS_EXTRACT` | Crop/ET/root-uptake physics | Preserve uptake/stress laws but consume hydraulic query contract, not solver internals. |
| `solute.f90` | `SPLIT_RETAIN_OPTIONAL_PHYSICS` | Optional solute transport component; Adapters; Results/diagnostics | Retain supported transport physics with explicit state/parameters. Reading/output routines move to adapters. |
| `wofost.f90` | `SPLIT_RETAIN_PHYSICS` | Crop/ET physics; Adapters | Keep WOFOST physical crop model behind common plant/crop contract; move reading/init wiring outward. |
| `wofost_soil_amendments.f90` | `RETAIN_OPTIONAL_PHYSICS` | Optional soil nutrient/management physics | Keep if supported; management inputs become explicit events/forcing. |
| `wofost_soil_balancecheck.f90` | `RETAIN_DIAGNOSTICS` | Results/diagnostics; optional nutrient component | Preserve balance check as qualification/runtime diagnostic, not hidden process mutation. |
| `wofost_soil_cropresidues.f90` | `RETAIN_OPTIONAL_PHYSICS` | Optional soil nutrient/management physics | Keep if within supported WOFOST soil scope, with explicit state/parameters. |
| `wofost_soil_declarations.f90` | `DECOMPOSE_GLOBALS` | Optional soil nutrient committed state; shared parameters; scratch | Classify every declaration by lifetime and move out of global module. |
| `wofost_soil_interface.f90` | `REPLACE_INTERFACE` | Crop/soil optional physics interface | Replace shared-global interface with typed source/sink/nutrient exchange contract. |
| `wofost_soil_orgmatn.f90` | `RETAIN_OPTIONAL_PHYSICS` | Optional soil nutrient physics | Preserve process equations with explicit state. |
| `wofost_soil_parameters.f90` | `RETAIN_PHYSICS_EXTRACT` | Optional soil nutrient shared parameters | Convert to immutable parameter construction/derivation. |
| `wofost_soil_rateconstants.f90` | `RETAIN_PHYSICS_EXTRACT` | Optional soil nutrient physics | Preserve rate equations with explicit inputs/outputs. |
| `wofost_soil_watern.f90` | `SPLIT_RETAIN_OPTIONAL_PHYSICS` | Optional soil nutrient physics; hydraulic query interface | Preserve nutrient-water coupling but obtain hydraulic information through stable physical contract. |
| `wofostnut.f90` | `SPLIT_RETAIN_OPTIONAL_PHYSICS` | Crop/nutrient optional physics; Adapters | Retain nutrient physics if in SWAP5 scope; explicit state/parameters and no global plant arrays. |
