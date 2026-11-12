# F-WOF-EXT01: authentic SWAP5 accepted-flux witness and PCSE durable receipt gates, 2026-10-17

**Bounded research evidence; no end-to-end scientific SWAP5–PCSE admission.**

## Executed real SWAP5 physical production-interface test

At SWAP5 research candidate `7f2f01827c4383354d04a4225e8249222b24a8b1`, focused [Actions run 39064643199](https://github.com/abhedwig-cell/SWAP5/actions/runs/39064643199) completed **SUCCESS**. The existing Fortran authentic-weather rooted crop/hydrology test passed its physical accepted-state bitwise gate **three times**. The new test-only exporter checked all three independent, identical reports of `F_WOF_EXT01_ACCEPTED_PAIR` and `F_WOF_EXT01_REAL_ACCEPTED_UPTAKE` against the three passing confirmation markers, rejecting inconsistent or missing witnesses rather than silently selecting one. The observed value in each was `1.0370706377336118E-03` for actual and potential uptake in the test's native integrated units.

Artifact `fwof-ext01-authentic-swap5-flux-log`, id **12112598609**, contains the original physical log and structured `fwof-ext01-accepted-witness.json`. The export is versioned `F-WOF-EXT01/SWAP-WITNESS/1`, marks `pcse_daily_import_permitted=false` and records `calendar_date=null` and `unit_conversion_to_cm=null` because neither may be fabricated or inferred from an unrelated PCSE fixture. Source-specific column/Fortran-day identifiers are recorded but are not a universal physical event identity.

The first exporter implementation failed its strict single-occurrence check in run `39064251428`, correctly revealing three repeated compatible physical confirmations. The repair accepts repeated witnesses only if **all** values and PASS counts match. This is a resolved test-harness error, not a scientific relaxation.

## Executed actual PCSE durable event/state journal

At PCSE research candidate `487a56faa99521c5bd5979d57ca77f13bfa91e46`, targeted [Actions run 39064599043](https://github.com/abhedwig-cell/pcse/actions/runs/39064599043) completed **SUCCESS**. Actual detached PCSE crop candidate preparation and a test-only atomic filesystem journal recorded a complete crop state and event receipts in the **same** JSON envelope, with SHA256 payload digest. The tests inject a failure after flushing/fsyncing the staged temporary file but before replacement: previously published state remains authoritative; retry and accepted event receipt survive journal reopening, duplicate events are rejected, and modified journal payload is refused. This is an atomic rename/recovery test, not a true machine power-loss, multi-process lock or production filesystem reliability guarantee.

## Architectural boundary and next explicit qualification

These successes establish (a) truthful, auditable extraction of a *real* accepted SWAP5 hydrological flux witness, and (b) bounded durability of a real PCSE crop candidate/receipt transaction under controlled local crash injection. They **do not establish** that both belong to the same calendar/meteorological/soil/column event, or that SWAP native integration units have been correctly transformed to PCSE cm/day. They also do not prove atomic commit across two independent hydrology and crop authorities. The direct Python–Fortran matched gerst trial and separate-process crop restart remain independently qualified in their earlier bounded tests.

**Decision: CONDITIONAL GO** for external WOFOST daily research architecture. **NO-GO** for production substitution or canonical merge. Positive end-to-end admission requires a SWAP5 same-calendar physical acceptance certificate with explicit column, unit, accepted revision and mass-balance provenance, consumed by the PCSE worker with identical forcing/parameters and coherent atomic commit/rollback semantics. Preserve the existing admitted SWAP5-WOFOST81 runtime.
