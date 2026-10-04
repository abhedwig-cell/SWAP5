# PPA-WU05-E runtime transaction and restart boundary

Date: 2026-10-04  
Status: `AUDITED_DESIGN_BLOCKER_NOT_PRODUCTION_INTEGRATED`  
Branch checkpoint: `a617e20361e7f7a873e655af2c87e89bba8fa77b`  
Canonical baseline used by this work unit: `integration/f-ci-canonical@9605fbb1622d96f4691117f66264f13b6dd3a47b`

## Finding

The current E1/E2 salt prototype is a pure trial transformation. It does not participate in the SWAP5 physical transaction, and it cannot safely be committed beside the water state by a second call. The production kernel owns one opaque physical-state object per committed revision; commit moves one validated candidate object into that committed carrier. Restart exports and restores that same physical object. A separate salt commit could therefore advance while water is rejected, lag a retry, or be absent after restart.

The smallest safe production integration must place the accepted salt mass in the same physical-state object and lifecycle as the matching water state, or introduce an explicitly qualified composite transaction boundary that atomically owns both. No such salt owner or composite boundary exists in the current source.

## Source-backed boundary

| Concern | Current authority | Consequence for salinity |
| --- | --- | --- |
| Transaction authority | `src/kernel/mod_kernel_transactions.f90`: `kernel_committed_state_t` owns one polymorphic `physical_state`; `kernel_candidate_state_t` carries one candidate; `kernel_commit_candidate` validates lineage/revision/time then moves the candidate physical object and advances one revision. | Salt cannot be independently committed without splitting physical revision authority. |
| Physical-state copy | `src/runtime/mod_fmr_serialized_reference_backend.f90`: `fmr_b110_physical_state_t` contains hydraulic continuation and optional physical states. `copy_b110_physical_state` manually copies its known fields; each subtype has its own clone override. | Any salt continuation must be included in every applicable clone path and cannot be trusted to intrinsic copying by assumption. |
| Restart envelope | `src/runtime/mod_fmr_committed_restart.f90`: Restart v2 exports the committed physical object plus lineage/revision/time and template identity. | Persisted salt must live in the committed physical payload or an atomic companion record owned by the same restart bundle. |
| Restart admission | `src/runtime/mod_fmr_restart_state_contract.f90`: backend and template layouts are matched through explicit concrete-state and optional-layout cases. | A salinity state layout needs explicit restart discrimination and validation; unknown combinations fail closed. |
| Crop root-input route | `src/runtime/mod_fmr_root_uptake_process_binding.f90` and `src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90`: shared crop uptake builds a hydraulic view from `kernel_committed_state_t` and evaluates uptake from that committed view. | Salinity concentration must be supplied from the matching committed/trial water state under a defined route. The current adapter has no salinity-state input. |
| Root composition | `src/process/mod_root_uptake_compensation.f90`: D2 supports the admitted drought and oxygen selectors and attributes those losses; unsupported selectors fail closed. | No salinity term or combination rule is admitted. |
| Salt prototype | `src/process/mod_solute_mobile_salt_state.f90`: mass is a standalone allocatable state; `advance_mobile_salt_trial` accepts water start/end arrays and root sink as arguments and returns a candidate. | Its candidate is not bound to the kernel's candidate provenance, transaction acceptance, or restart state. |
| Richards water flux output | `src/solver/mod_soil_water_solver_contract.f90`: a solve result exposes top and bottom flux rates and candidate water content, but no internal face-flux vector. The FMR runtime supplies signed subsurface sources, drainage sinks, and the final `qrot` sink to the solve. | Internal net interval-mean face fluxes must be reconstructed conservatively before they can drive E1 salt transport. |

## Conservative internal water-flux reconstruction

The FMR runtime accounts positive input at the top as `-solver_top_flux` and positive outflow at the bottom as `-solver_bottom_flux` (`account_external_fluxes` in `src/runtime/mod_fmr_serialized_reference_backend.f90`). Thus a new salinity bridge using positive-downward coordinates maps the reported boundary rates to `q_down = -q_solver` at both ends.

For node `i`, continuity gives the signed interval-mean internal face rate:

`q_down(i+1) = q_down(i) + net_source(i) - (theta_end(i)-theta_start(i))*dz(i)/dt`

Here `net_source = subsurface_irrigation - drainage - final_root_sink`; additional physical terms must be included before this identity is used when their routes are active. The independently reported Richards bottom flux closes the recurrence. A failed closure must reject the salt candidate rather than publish an invented profile.

`src/process/mod_solute_water_face_flux_reconstruction.f90` now implements this continuity reconstruction as a pure fail-closed helper. Its manufactured test recovers downward, upward, and reversing internal fluxes and rejects inconsistent bottom closure, zero-duration, and nonfinite-boundary inputs at O0/O2. It has not yet been called by the live FMR runtime. The helper returns interval-mean net fluxes; the advection-only salt update still needs source review and qualification for this temporal discretization, and this reconstruction does not supply dispersive flux.

## State-layout design issue

The FMR physical carrier has several explicit optional-state families (temporal history, macropore reduction, fixed-weir surface water, evaporation continuations, RFM). Some are intentionally mutually exclusive today. Adding a single new `salinity` subtype would not by itself establish that salinity can coexist with every applicable admitted continuation. Conversely, adding an optional salt component to the common base requires explicit rules for inactive versus active layouts, state validation, parameter/template identity, and compatibility with the existing no-salinity route.

The next implementation checkpoint must decide and record one of these designs before changing shared runtime interfaces:

1. a compositional physical-state representation with typed optional components and explicit template/layout validation; or
2. a bounded salinity physical-state family, with a complete coexistence matrix and clone/restart/restore handling for each admitted combination in its scope.

The choice must retain the existing behavior and layout of salinity-disabled cases within their admitted equivalence requirements. It must not add a second commit API or let Jarvis own any salt state.

## Required transactional proof before root-stress integration

The runtime binding work must use the real accepted water candidate and root sink for each physical attempt. Before Jarvis integration, qualification must demonstrate:

- an accepted interval advances water and salt under one lineage/revision/time transition;
- a rejected candidate and discard leave both committed states bitwise unchanged;
- retry starts from the same accepted water and salt, with no rejected candidate leakage;
- fresh-process restart restores matching water and salt state and reproduces the next interval;
- changed forcing after restart starts from restored committed salt mass, with concentration re-derived from matching water content;
- restart rejects missing, mismatched, wrong-layout, or invalid salt continuation;
- water and salt receipts remain separate, and salt closure accounts for boundary, inter-node, and root salt fluxes without altering the water receipt;
- salt transport consumes the candidate root-water sink exactly once, while salinity stress reads concentration and never commits salt;
- no Jarvis or root-composition call can publish salt state.

## Remaining transport gate

Atomic ownership is necessary but not sufficient. The current mobile-salt prototype uses explicit single-step upwind advection and no dispersion, drainage, boundary scheduler, or internal transport substeps. The live Richards execution can contain multiple physical substeps and retries. A production transport implementation must bind the salt fluxes to those accepted water substeps (including the correct candidate root sink), qualify positivity/stability and mass closure per substep and over the interval, and define salt restart initialization. These requirements remain open and are not discharged by this runtime-boundary audit.

## Directional-advection evidence boundary

The interval-mean continuity reconstruction above determines only the **net signed** water transfer through each face. It is not sufficient evidence for conservative salt advection when flow can reverse inside the reconstructed interval. For example, equal-duration face flow at (+Q) and (-Q) has zero signed mean, while it still transports water and dissolved salt in both directions; applying zero mean flux to the salt state loses both transfers. Endpoint storage and net sources cannot distinguish that history from a genuinely stagnant face.

Therefore a closed water-continuity residual does not by itself admit the reconstructed mean flux to salt transport. A live transport binding must consume an ordered trace of accepted Richards substeps with face flux and duration for each substep (or another independently qualified representation that preserves the within-interval flow direction and order). The trace must be candidate-local so a rejected FMR trial discards it with the water candidate. If an active route cannot provide a complete trace, including its boundary and source/sink terms, E1 transport must reject that candidate. The current mean-flux prototype remains a closure diagnostic only.

## Scope ceiling

This audit establishes a source-backed transaction/restart blocker and an integration contract. It does not qualify salt transport, salt initialization, salinity response under a live crop, Jarvis combinations, solute uptake equivalence, or any production salinity capability. The current salinity fail-closed behavior remains required.
