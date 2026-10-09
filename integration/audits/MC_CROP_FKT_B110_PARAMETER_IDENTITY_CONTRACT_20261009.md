# MC-CROP01: B110 parameter identity and F-KT committed crop forcing contract

Status: PROPOSED, NOT ADMITTED. Canonical baseline: `799b9a70fc1e0a436d8c32509aa640d557fbf749`.

## Existing owner interfaces and proof gap

- `src/runtime/mod_fmr_serialized_reference_backend.f90`: `fmr_b110_physical_parameters_t` carries `parameter_set_id`, `active_nodes`, `z`, `dz`, heat option. `fmr_b110_physical_state_t` carries `active_nodes`, heads, water contents and optional heat continuation, but not its parameter identity.
- `src/kernel/mod_kernel_transactions.f90`: `kernel_advance_interval` checks committed time and calls `model%execution_admitted(parameters,...)` and `configure_parameters(parameters)`. It does not compare these input parameters against a certificate in the committed physical state. `kernel_commit_candidate` checks candidate lineage/revision/time and installs the candidate's physical state.
- `fmr_new_b110_committed_state` clones physical state without B110 parameters. The trusted reconstruction entrypoint also reconstructs generic physical state without B110 parameter identity.
- Existing accepted hydrothermal F-KT samplers authenticate committed lineage/revision/time and sample from one accepted clone. The crop B110 grid preflight checks internally coherent z/dz. Neither establishes that z/dz are the parameters that governed the accepted head and heat.

A false positive can have identical `active_nodes` and a distinct ordered `dz`. Matching `parameter_set_id` alone does not fix this because its assignment is caller-controlled before model configuration.

## Required owner contract before physically authorized crop forcing

1. The **B110 column initialization owner** must bind an immutable identity of ordered grid `z(:),dz(:)`, `active_nodes`, `parameter_set_id`, and relevant heat option to the committed F-KT physical state at initial construction. Validate midpoint/bottom geometry and exact positive finite thickness; refuse invalid/missing identity rather than setting a default.
2. The **F-KT advance admission path** must verify that the bound parameter carrier is identical to the committed physical identity **before** `configure_parameters` or trial starts. Parameter reconfiguration with the same number of nodes but different z/dz or parameter-set identity must fail without changing committed physical state or revision. Generic F-KT and alternative solver interfaces must retain their existing admitted default behaviour; an explicit typed B110 extension or owner-issued validation hook is required rather than silently requiring B110 fields of all models.
3. The **F-KT commit path** must preserve that exact identity and must reject a candidate missing or altering its identity, in addition to existing lineage, revision and time checks. Reject/rollback must not update identity or cache.
4. The **trusted reconstruction owner** must reconstruct identity atomically with the matching B110 physical clone and provenance, and refuse mismatched or absent identity for the newly certified crop route. Older generic Restart v1 remains bounded and must not be re-described as supporting the new route.
5. The **crop read-only view** must only expose z/dz and heat authorization from the certified committed owner, match the current lineage/revision/time, then apply admitted B110 geometry and B1.11 nodsow and weighted-pF samplers. Do not accept external dz, nodsow, heat policy or a caller-minted parameter receipt as authorization.
6. The **event authority** remains the existing F-KT crop transaction owner. A certified sample still does not publish preparation, sowing, germination or emergence without accepted lifecycle receipt and event identity.

## Negative and positive acceptance matrix

- Same `active_nodes`, permuted `dz`: reject parameter switch and crop forcing.
- Same lengths and geometrically consistent but different `z/dz`: reject.
- Same `z/dz`, different `parameter_set_id`: reject unless an explicit same-identity rebind protocol has been accepted.
- Identical parameter ID, changed thickness or changed heat option: reject.
- Foreign lineage, stale revision, changed accepted time: reject crop source acquisition.
- Trial/retry/rollback: physical state, grid identity and revision unchanged on rejection.
- Candidate with altered/missing identity: reject commit without partial publication.
- Trusted restart with swapped grid, wrong heat flag or foreign parameter certificate: reject atomically.
- Genuine same-identity restart: uninterrupted and reconstructed paired hydrothermal crop source values identical at O0/O2.
- B1.11 fractional depth, `small=1.0e-6`, `ztempsow+1.0e-8` and heat-off sowing guard: source-oracle equality.
- Preserve existing B19/MICRO, root uptake, water and mass balances, physical/calendar paired restart, and all applicable current F-CI gates.

## Admission limit and sequencing

This is an interface decision proposal, not an implementation/qualification claim. Do not change the shared F-KT kernel or B110 backend while concurrent owners are changing the same interfaces without reconciling them. Implement the owner-issued identity and its mutation/restart guards in a separate PR, persist first, run local O0/O2 and then exact-head F-CI. Only then may crop forcing be permitted to consume the certified grid.

The next scientific gates remain source-bound `hprep`, `hsow`, `tsoil(nodsow)`, `SWHEA=1`, daily accepted `tav`, and `SWGERM=2` moisture thresholds, followed by transactionally accepted physical lifecycle and two-crop restart.
