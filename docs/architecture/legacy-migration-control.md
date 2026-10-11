# Control, I/O and accounting

**Part of:** [Legacy-to-target migration map](legacy-migration.md)  
**Baseline:** SWAP 4.3.1

| Legacy file | Migration action | Target destination(s) | Migration intent |
| --- | --- | --- | --- |
| `MOD_meteo.f90` | `SPLIT` | Adapters; forcing domain; Surface/atmospheric physics | File reading/loading belongs to adapters. Physical forcing transformations/interception preparation belong to typed atmosphere/process services. |
| `MOD_out_PEARL_ANIMO.f90` | `ADAPTER` | Results/diagnostics; external adapters/coupling integration | Keep compatibility/export mapping outside the kernel. Do not expose kernel internals to PEARL/ANIMO output code. |
| `MOD_runon.f90` | `SPLIT` | Adapters; forcing domain; Surface/atmospheric physics | Move reading/loading outward; represent runon as explicit forcing/boundary input. |
| `description.f90` | `ADAPTER_OR_SHARED_METADATA` | Adapters; Public API metadata | Keep descriptive metadata where useful, but not as a physics/global-state dependency. |
| `fluxes.f90` | `SPLIT` | Kernel interval executor; Results/diagnostics; process interfaces | Preserve physically meaningful flux accounting; source fluxes from explicit process outputs rather than global arrays. |
| `initialize.f90` | `SPLIT` | Adapters; Runtime; Kernel/process initializers | Separate parsing-derived setup, immutable parameter construction, committed initial state construction and worker/runtime setup. |
| `integral.f90` | `SPLIT` | Results/diagnostics; Kernel process accounting | Preserve physical balance accounting but remove output/global-state coupling. Accepted-trial accounting must align with transaction commit. |
| `macroporeoutput.f90` | `ADAPTER` | Results/diagnostics; Legacy/external adapters | Macropore diagnostics are produced by physics; formatting is external. |
| `readswap.f90` | `ADAPTER` | Legacy/external adapters | Parsing and legacy validation remain available outside the kernel; convert to typed parameter/state/forcing/configuration objects. |
| `swap.f90` | `SPLIT_AND_RETIRE` | Public API; Runtime; Coupler; Kernel interval executor; Results/diagnostics | High-risk mixed-responsibility file. Extract lifecycle, exchange, scheduling, trial execution and output coordination; retire the legacy monolithic control flow when equivalent gates pass. |
| `swap_base.f90` | `SPLIT` | Adapters; Runtime; shared parameter/numerical configuration domains | Move file/environment/configuration reading outward. Typed physical/numerical configuration remains, path and environment logic does not enter the kernel. |
| `swap_csv_output.f90` | `ADAPTER` | Results/diagnostics; Legacy/external adapters | CSV serialization stays outside kernel and consumes typed results. |
| `swap_main.f90` | `ADAPTER_THEN_THIN` | Public API; Runtime | Keep only a thin executable/legacy entry shell. No physics or lifecycle policy in the final entry point. |
| `swapoutput.f90` | `ADAPTER` | Results/diagnostics; Legacy/external adapters | Result production must be typed; legacy file formatting becomes an output adapter. |
| `timecontrol.f90` | `SPLIT_AND_RETIRE` | Runtime; Kernel interval executor; numerical configuration | Separate generic interval/event scheduling from solver retry/timestep policy. Remove hidden day/calendar assumptions and legacy task-code orchestration. |
| `watstor.f90` | `RETAIN_PHYSICS_EXTRACT` | Kernel; Results/diagnostics | Retain water-storage calculation as a pure/state-based physical/accounting function and use it in hard mass-balance gates. |
