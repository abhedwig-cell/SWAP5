# F-VQ08 — Real B1.10 temporal-characterization readiness

F-VQ08 is qualification-only and starts from the qualified F-VQ07 head `4ae2fc87970d46ff2103553930e583dd05a59f0b`. It changes no SWAP production source, physics, solver policy, timestep policy or mass tolerance.

## Question

Can the current repository already support a reproducible, source-bound B1.10 `full_step` versus `two_half_step` characterization from one committed physical starting state, with enough process-state coverage to derive a production temporal profile?

The pre-test answer is **no**. F-VQ08 therefore qualifies only the evidence boundary and prerequisites if its gate is green; it does not qualify the missing capability.

## Existing evidence

F-VQ05 defines eight required endpoint metrics (`h_cm`, `theta`, `pond_cm`, `gwl_cm`, `volact_cm`, `ldwet_cm`, `spev_cm`, `saev_cm`) and four lagged diagnostics. Every production numeric limit remains null. Its normalized threshold is explicitly not a physical tolerance, hard mass conservation is a separate absolute gate, and solver convergence tolerances may not be reused as temporal-accuracy limits.

F-CI10 and F-CI11 contain real, source-bound Hupsel evidence with hard mass PASS and O0/O2 identity. F-CI11 also records real full-versus-split differences, but explicitly leaves `temporal_error_metric_qualified=false` and states that the detailed raw local matrix remains outside canonical Git. Those values are observations, not production acceptance limits.

## Process-scope boundary

The qualified Hupsel profile has `SWCROP=1`, `SWIRFIX=1`, `SWHEA=1` and `SWSOLU=1` (with drainage active; snow and macropores inactive). The current water-focused temporal checkpoint does not claim complete rollback/endpoint coverage for all those active crop, irrigation, heat and solute states. Therefore water-domain temporal observations cannot silently become a complete-process temporal qualification.

## Reproducibility boundary

The real F-CI07 full B1.10 runner is source-bound, but it requires three externally supplied assets: `FCI07_B1_10_SOURCE`, `FCI07_TTUTIL_ROOT` and `FCI07_CASE`. It is a physical rerun/rollback gate and is not itself a full-versus-two-half temporal probe. The current checked-in qualification path therefore does not yet provide a self-contained real temporal-characterization execution route.

## Promotion requirements

A later production temporal profile requires exact reconstructible source/case/toolchain assets, a source-bound full/two-half probe from one committed state, same-`t1` comparison of all required metrics, independent hard-mass PASS for both paths, explicit active-process coverage, immutable raw evidence, and independently justified per-metric physical limits with units.

Until then:

- real B1.10 temporal characterization remains unqualified;
- production temporal numerical profile remains unqualified;
- production `execute_reference_interval` remains fail-closed;
- complete optional-process temporal scope remains unqualified;
- hard mass conservation remains absolute and separate.
