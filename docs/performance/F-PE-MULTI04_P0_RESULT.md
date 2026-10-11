# F-PE-MULTI04 P0 result — production worker-local backend ownership

Date: 2026-09-27

Status: `PASS_OWNERSHIP_DEFAULT_SERIAL`

PR:
`#666 — F-PE-MULTI04: production application-context worker-local groundwater parallel admission`

Authority:
- exercised head: `1ada50e27524a362aff6fd2bac8d69bf8995b7f9`;
- canonical base: `0ce2bbf8eb4bfdbbfc7702f1c10e11410f7aec88`;
- PPA-WU01 workflow run: `36314465171`;
- owner-qualification job: `108606428774`.

## Scope

P0 introduces only production ownership/configuration plumbing.

It does not parallelize `application_context_trial_cell_heads`.

The existing serial participant registry remains bound to the existing serial Reference backend.

Added production capability:
- explicit `groundwater_parallel_workers` configuration;
- default value = 1;
- admitted configuration values = 1, 2, 4;
- worker counts >1 are restricted to the mode-5 groundwater profile;
- independent worker-local `fmr_serialized_reference_backend_t` objects are allocated and initialized by the production bootstrap;
- worker-local backend storage is released by the existing production-owner close path.

## Production owner gate

PASS.

The existing PPA-WU01 production application owner gate passed with O0/O2 authority.

Observed MULTI04 markers:
- `FPE_MULTI04_P0_DEFAULT_SERIAL_WORKER_COUNT=PASS`;
- `FPE_MULTI04_P0_WORKER_LOCAL_BACKEND_2_OWNERSHIP=PASS`;
- `FPE_MULTI04_P0_WORKER_LOCAL_BACKEND_4_OWNERSHIP=PASS`;
- `FPE_MULTI04_P0_UNSUPPORTED_WORKERS_FAIL_CLOSED=PASS`;
- `FPE_MULTI04_P0_NON_GROUNDWATER_PARALLEL_FAIL_CLOSED=PASS`.

Existing owner authority also closed:
`PPA-WU01 PRODUCTION APPLICATION BOOTSTRAP OWNER GATE PASS`.

## Default behavior

PASS.

The default production configuration remains one worker.

No production trial dispatch changed in P0.

Therefore the existing default serial application-context execution route remains the authority.

## Lifetime and fail-closed behavior

PASS under the production owner test.

- 2-worker mode-5 bootstrap initializes and closes cleanly;
- 4-worker mode-5 bootstrap initializes and closes cleanly;
- unsupported worker count 3 fails closed;
- a non-groundwater production profile requesting >1 groundwater worker fails closed;
- worker-local backend storage is deallocated on owner close.

## Fixed-interface closeout workflow classification

The branch-triggered fixed-interface closeout failed before executing its physical end-to-end case.

Failure:
`mod_reference_richards_temporal_indicator.f90` could not import
`mod_b110_direct_retention_provider.mod`.

Classification:
`HARNESS_COMPILE_LINEAGE_DEFECT`.

Evidence:
- the failing end-to-end harness file is byte-identical between current canonical and the MULTI04 head;
- the temporal-indicator source is byte-identical;
- the direct-retention provider source is byte-identical;
- the harness compile list places the temporal indicator in the compilation graph without compiling the required direct-retention provider module first.

No MULTI04 production source is implicated by this failure.

The failure is retained as negative CI/harness evidence and is not treated as permission to alter physics or the P0 ownership candidate.

## Decision

P0 closes:

`ADVANCE_TO_P1_TRIAL_BACKEND_OWNERSHIP`

P1 may now add the production trial-on-worker-backend seam, but parallel scheduling remains blocked until:
- the worker that creates each live candidate is recorded;
- discard and commit use the correct backend owner;
- default one-worker behavior remains unchanged;
- failure cleanup is deterministic.
