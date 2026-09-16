# F-CI04 Qualification Record

**Work unit:** F-CI04  
**Branch:** `integration/f-ci-canonical`  
**Oracle:** B1.10  
**B1.10 source manifest:** `2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`

## Materialized production source

- `src/runtime/mod_canonical_contracts.f90`
- `src/runtime/mod_canonical_interval_runtime.f90`

No B1.10 physical adapter is admitted in this unit.

## Focused qualification

GitHub Actions workflow run: `34081431284`

- F-CI03 regression job `101617309302`: PASS
- F-CI04 canonical runtime job `101617332887`: PASS
- compiler modes: strict `-O0` and `-O2`

The F-CI04 gate also reruns the F-CI03 source-provenance gate before compiling the new runtime.

## Qualified semantics

PASS:

- explicit state / forcing / numerical-config / result categories;
- forcing passed separately through the physical-model preparation contract;
- generic real-valued `[t0,t1]` runtime;
- repeated accepted internal transaction steps until requested `t1`;
- requested interval is externally atomic;
- incomplete or failed interval does not alter externally committed physical state;
- transaction mass defect remains a hard rejection;
- bounded committed-substep count;
- exact rerun repeatability in the deterministic qualification backend;
- no file I/O in the canonical runtime modules;
- wholesale A23BU physical adapter remains absent.

## Explicit non-claims

F-CI04 does not claim:

- a B1.10 physical adapter;
- complete unrounded accepted-interval physical mass accounting;
- qualified physical sub-day B1.10 execution;
- scheduled irrigation continuation across arbitrary sub-day boundaries;
- crop/WOFOST continuation qualification;
- throughput/reference policy convergence.

`canonical_mass_accounting_t%complete` therefore remains false on the generic runtime path. This is intentional and fail-closed.

## Decision

`PASS_CANONICAL_RUNTIME_PHYSICAL_ADAPTER_BLOCKED`

The next safe integration unit is implementation of the B1.10 physical adapter against the F-CI04 seam. That implementation must preserve the data separation and generic-time contract and may not reintroduce the B1.6 integer-day A23BU projection as the canonical API.
