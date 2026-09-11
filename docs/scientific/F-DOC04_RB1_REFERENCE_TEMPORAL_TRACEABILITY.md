# F-DOC04 — RB1 Reference Richards and Temporal Acceptance Traceability

## Scope

F-DOC04 populates traceability for exactly two frozen RB1 capabilities:

- `RB1-SW-REFERENCE`: Full Richards REFERENCE route in the frozen RB1 hydraulic/profile scope.
- `RB1-TIME-REFERENCE`: restricted temporal acceptance machinery with an explicit finite positive `H_budget` where exercised.

This is documentation and traceability work only. F-DOC04 does not change production source, reference material, physics, solver behavior, tolerances, the 15-capability RB1 denominator, or immutable RB1 scientific/release authority.

## Governing rule

Release qualification is not a substitute for theory provenance or a complete verification graph. Where an authority is missing, F-DOC04 records a gap instead of manufacturing one from source presence, a qualified implementation seam, or RB1 release PASS evidence.

No capability in this workunit is claimed `FULLY_TRACED`. F-DOC04 does not claim Status A readiness, Status A compliance or Status AA compliance.

## RB1-SW-REFERENCE

The release capability is already PASS in F-RB01 and limited to `SWKIMPL=0`, `SWSOPHY=0`, the frozen reference boundary profile, with RossFast excluded.

The frozen RB1 source contains an explicit soil-water solver contract and the reference Richards implementation chain. F-DOC04 pins representative source objects by exact Git blob identity, including:

- `src/adapter/mod_reference_richards_legacy_binding.f90`
- `src/solver/mod_soil_water_solver_contract.f90`
- `src/solver/mod_reference_linear_solver.f90`
- `src/solver/mod_reference_richards_state_binding.f90`
- `src/solver/mod_reference_richards_temporal_indicator.f90`
- `src/runtime/mod_fmr_serialized_reference_backend.f90`

F-SI19 independently qualifies the reference linear-solver seam within its own bounded scope. Its qualified `mod_reference_linear_solver.f90` blob is exactly the same blob present in the frozen RB1 canonical source. This is useful implementation and numerical-method traceability, but F-SI19 is not promoted into a complete Full Richards theory authority.

F-DOC04 therefore keeps the Full Richards T1/theory binding explicitly open: no single controlled authority was identified that by itself closes the complete physical theory and full equation-to-test graph for the entire RB1 reference route. The RB1 release PASS remains valid; the documentation maturity claim remains bounded.

## RB1-TIME-REFERENCE

The temporal chain is stronger and can be made more explicit without broadening its scientific claim.

### Scientific policy qualification

F-VQ34 independently qualified the remediated Richards head-budget certificate within a frozen scope. The qualified relation is:

`C_h = B_inf / H_budget`

The budget is owned by explicit numerical configuration. A valid value must be supplied, finite and greater than zero. Missing or invalid budget means that the certificate is unavailable and the path fails closed. Hard mass rejection takes precedence over certificate acceptance.

Crucially, F-VQ34 sets `default_H_budget = null`. It neither selects nor recommends a numeric application budget, does not establish a universal temporal tolerance, does not establish `B_inf` as a nonlinear true-error upper bound and does not claim monotonic reduction of `C_h` with shorter `dt`.

### Materialization and negative provenance

F-CI21 materialized the dependency-closed temporal certificate and replayed the SI25, VQ30, VQ31, VQ32 and VQ34 evidence chain. It explicitly preserves the failed F-VQ33 result as negative evidence. F-VQ33 is not reinterpreted as a pass and its rejected backend is not used as positive authority.

F-CI21 also retains `default_H_budget = null` and states that neither an application budget nor a universal temporal tolerance is selected.

### RB1 replay and current preservation

The frozen F-RB01 temporal runner uses:

- immutable temporal authority `F-CI21@697755068253cfb5a2f838c63894e1609a85ff51`;
- current dependency authority `F-CI40@d81ef430ebaa601469a165dfc5b9866b813b71aa`;
- replay of the F-CI21 SI25/VQ30/VQ31/VQ32/VQ34 gates;
- exact comparison of the temporal dependency surface against F-CI40.

It emits separate PASS markers for frozen temporal scientific authority and current temporal dependency preservation. That separation is retained here.

## H_budget boundary

F-DOC04 deliberately does not answer the application-policy question "what numeric `H_budget` should be used?". That requires application/runtime provenance and, for groundwater coupling, must remain distinct from any application-specific total head-error budget and from coupling-window/discretisation error attribution.

A documentation change must never silently turn the F-VQ34 normalization certificate into a universal groundwater-head accuracy requirement.

## Remaining gaps

For `RB1-SW-REFERENCE`, the principal open documentation gaps are a controlled complete T1 theory binding and a complete equation-to-test graph for the full reference Richards route.

For `RB1-TIME-REFERENCE`, the scientific certificate policy is qualified in its frozen scope, but application-specific `H_budget` selection remains an external policy dependency. A universal temporal or groundwater-head accuracy budget is explicitly not qualified.

These gaps do not invalidate RB1 release qualification. They bound the maturity of the theory-code-evidence traceability claim.

## Nonclaims

F-DOC04 does not reopen RB1, change source/reference/tolerance/physics/solver behavior, qualify RossFast, select a default `H_budget`, establish a universal temporal tolerance, establish a universal MODFLOW/SWAP head budget, or claim Status A/AA.
