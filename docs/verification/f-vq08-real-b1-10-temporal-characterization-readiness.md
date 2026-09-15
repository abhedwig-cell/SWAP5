# F-VQ08 — Real B1.10 temporal-characterization readiness

Status: **`QUALIFIED_TEMPORAL_CHARACTERIZATION_READINESS_ONLY`**.

Qualified test postimage: `b097203be56b9891c8e73ecdcc84f76c94b33656`. VQ run `34117585838`, F-VQ08 job `101727896875`, PASS with 11/11 F-VQ08 guard tests, `FCI10_GATE_PASS`, `FCI11_GATE_PASS` and a valid real-runner shell contract. Documentation run `34117585832` also passed.

F-VQ08 is qualification-only and starts from the qualified F-VQ07 head `4ae2fc87970d46ff2103553930e583dd05a59f0b`. It changes no SWAP production source, physics, solver policy, timestep policy or mass tolerance.

## Qualified boundary

F-VQ05 defines eight required endpoint metrics (`h_cm`, `theta`, `pond_cm`, `gwl_cm`, `volact_cm`, `ldwet_cm`, `spev_cm`, `saev_cm`) and four lagged diagnostics. Every production numeric limit remains null. Its normalized threshold is explicitly not a physical tolerance, hard mass conservation is a separate absolute gate, and solver convergence tolerances may not be reused as temporal-accuracy limits.

F-CI10 and F-CI11 contain real, source-bound Hupsel evidence with hard mass PASS and O0/O2 identity. F-CI11 records real full-versus-split differences but explicitly leaves `temporal_error_metric_qualified=false`; the detailed raw local matrix remains outside canonical Git. These values are observations, not production acceptance limits.

The qualified Hupsel profile has `SWCROP=1`, `SWIRFIX=1`, `SWHEA=1` and `SWSOLU=1` (with drainage active; snow and macropores inactive). The current water-focused temporal checkpoint does not claim complete rollback/endpoint coverage for all those active crop, irrigation, heat and solute states. Water-domain temporal observations therefore cannot silently become a complete-process temporal qualification.

The real F-CI07 full B1.10 runner requires externally supplied `FCI07_B1_10_SOURCE`, `FCI07_TTUTIL_ROOT` and `FCI07_CASE`. It is a physical rerun/rollback gate and is not itself a full-versus-two-half temporal probe. The checked-in qualification path therefore does not yet provide a self-contained real temporal-characterization execution route.

## Still blocked

A later production temporal profile requires exact reconstructible source/case/toolchain assets, a source-bound full/two-half probe from one committed state, same-`t1` comparison of all required metrics, independent hard-mass PASS for both paths, explicit active-process coverage, immutable raw evidence, and independently justified per-metric physical limits with units.

Accordingly F-VQ08 does **not** qualify real B1.10 temporal characterization, a production temporal numerical profile, production `execute_reference_interval`, or complete optional-process temporal scope. Hard mass conservation remains absolute and separate.
