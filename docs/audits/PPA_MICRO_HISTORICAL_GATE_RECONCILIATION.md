# PPA-MICRO02–06 historical gate reconciliation

Status: scoped evidence assembled; owner disposition and persisted rerun remain open. PR #1077 remains a draft; canonical admission is false.

## ELASTIC09 source-scope check

On PR #1077 merge qualification run 37432003002, the ELASTIC09 application behavior markers passed at O0 and O2, including the heterogeneous case, fail-closed case and byte-identical output check. Its final guard failed because the historical ELASTIC09 script permits only `src/runtime/mod_fmr_production_application_bootstrap.f90` in that original workstream's production delta. The MICRO candidate adds four production paths: `src/process/mod_root_micro_de_willigen_process.f90`, `src/runtime/mod_fmr_micro_mvg_table_binding.f90`, `src/runtime/mod_fmr_production_application_bootstrap.f90` and `src/runtime/mod_fmr_serialized_reference_backend.f90`.

This is a workstream source-boundary failure after a green ELASTIC09 behavioral suite. It does not establish a MICRO numerical or bootstrap regression. The gate stays visible; ELASTIC09's owner must classify its original single-source scope as outside this bounded MICRO admission. No guard or scientific tolerance is weakened here.

## PUB-P2E04 explicit compile closure

The PR merge runs 37432003343 (failure census) and 37432003316 (Stage B/C) fail during compilation because the explicit module arrays omit already-required providers. The original census script also fails on canonical preimage `integration/f-ci-canonical@e5eab995ef04fc813dd644025fb0f32e4f5050a1` with the same missing `mod_drainage_extended_exchange.mod`, demonstrating that the failure predates MICRO.

Adding these four compile-only dependencies to both P2E04 runner lists repairs the module closure:

- `src/solver/mod_b110_root_sink_provider.f90`
- `src/process/mod_drainage_extended_exchange.f90`
- `src/solver/mod_b110_direct_retention_core.f90`
- `src/solver/mod_b110_direct_retention_provider.f90`

With only those source-list additions, both the frozen 162-case census and frozen Stage B/C sweep pass locally at O0/O2 on both source trees: canonical preimage `52d5b774ce12369a7113e39445886d463fbe7dd2` and MICRO candidate `ac822aafd5403547a2c7ffad5c3ba02c9fa36496`. The full logs are byte-identical between preimage and candidate for each gate. Census combined output SHA256: `2f1112b5a62170094614da27b2b4fd1d414a925109a1b9fc347bcb91ab2933df`; Stage B/C combined output SHA256: `890489b2d78216dd09c0ecd1a0d3825d9aef801986f4b73d9300620646b4c587`. The RossFast execution firewall, preregistered targets and tolerances are unchanged. A persisted workflow rerun on the corrected scripts is still required.

## F-KT22 EB-I25 preservation

PR merge run 37432003245 fails at the external full-half outflow fixture after the two-half aggregation and missing-top-donor fail-closed markers pass. Replaying the unmodified gate on canonical preimage `e5eab995ef04fc813dd644025fb0f32e4f5050a1` failed at the same assertion. This is a separate F-KT22 owner issue and is not attributed to MICRO or counted as qualified by the baseline reproduction.

## Admission boundary

The PPA-WU05B15 full low-air preservation qualification must pass on the persisted PR merge postimage. The ELASTIC09 owner must disposition its historical scope-only guard, the corrected PUB-P2E04 runners need persisted reruns, and F-KT22 remains separately owned. None of these red checks is erased by the bounded local results above. The central F-CI owner records canonical admission only after checking the final merge tree and the controlling evidence.