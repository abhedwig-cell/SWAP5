# F-MIG431-INT13 Rutter source-window migration

Status: PREREGISTERED / AUDIT IN PROGRESS  
Canonical base: `9605fbb1622d96f4691117f66264f13b6dd3a47b`  
Branch: `work/f-mig431-int13-rutter-stateful-forcing`

## Scope

Finish the SWAP 4.3.1/B1.11 `SWINTER=3` migration by auditing the existing restricted Hupsel Rutter process and, if its source authority and physical contract permit, binding Rutter as a transactional atmospheric-forcing processor. The process owns canopy liquid storage and accepted source-window progress. Richards owns neither. A Richards reject or retry must not reprocess accepted precipitation.

This work does not reopen the admitted `SWINTER=1/2` physics. It reuses the method-neutral source-window machinery admitted by INT12-P0 and the non-Rutter daily/detailed application paths only where their contracts actually fit Rutter.

## Reconciled authority

- Canonical branch/head: `integration/f-ci-canonical` at `9605fbb1622d96f4691117f66264f13b6dd3a47b`.
- INT12-P0, C, D and E are canonically closed. INT12-E explicitly excludes Rutter.
- PPA-WU04 identifies Rutter as a physical canopy-water state, distinct from the source-window aggregate methods `SWINTER=1/2`.
- Existing Rutter implementation and admission: `src/process/mod_rutter_interception_process.f90`, `src/runtime/mod_fmr_rutter_output_application_binding.f90`, F-APP05/F-APP08. The production gap register limits this to a Hupsel composition and explicitly freezes capacity-loss semantics; it does not establish a generic source-window or Richards-independent forcing application.
- The exact B1.11 identity is recorded by PPA-WU04: `MOD_meteo.f90` SHA-256 `99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f`, `swap.f90` SHA-256 `39d1cbd93dbd0f99505e92ef94ac0d23bddb496529c280397d2d7c2b7eb9b58a`, and member-manifest SHA-256 `24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`.
- The canonical checkout contains the deterministic B1.11 reconstruction tooling and identities, but not the exact B0 distribution archive or reconstructed `MOD_meteo.f90` member. Existing Hupsel observations and source-hash records are not a substitute for inspecting that member. Recovery of the exact member is a required audit gate, not permission to use a later public SWAP version as the equation oracle.
- No open PR or branch search result identified an existing INT13/Rutter successor at reconciliation. INT13 is therefore available as a provisional identifier.

## Initial falsification target

The current process reports a maximum event timestep when the canopy fills or empties, but also clips the end-of-interval canopy store to capacity. Its output contract must be tested for a longer-than-event call. With full cover, empty storage, capacity 0.1 cm, gross rain 1 cm/day, zero evaporation and a one-day interval, the routine reports all rain as intercepted while publishing only 0.1 cm of storage. Unless the caller splits the forcing interval at the event and sends the post-event rain to the soil, 0.9 cm is unaccounted for. This experiment characterizes the current API; it does not yet establish whether B1.11 has the same event-driving requirement or whether the accepted Hupsel caller satisfies it.

## Required decisions and gates

1. Reconstruct and inspect exact B1.11 Rutter equations, call sites, event ordering, capacity transition, rain/irrigation/snow interactions, canopy-change semantics and mass accounting.
2. Establish independent analytical references for empty/filling/full/drying cases and compare a single source window against event-split and meteorological-record refinements.
3. Select either a source-window Rutter integration whose accepted result is invariant to Richards retry/substep patterns, or record a specific physical/legacy reason it cannot be used.
4. Persist canopy storage and source-window progress atomically; verify reject, retry, restart and detailed-meteorology continuation.
5. Preserve the admitted `SWINTER=0/1/2`, Black and Boesten surfaces in their declared envelopes and fail closed for unsupported combinations.
6. Run local O0/O2 physics, mass, source-window, transaction and restart gates before deciding whether a dedicated persisted qualification run and bounded canonical admission are justified.

## Architecture invariants

Affected invariants: 3, 4, 7, 9, 13, 23, 26, 29 and 30. The intended change makes process state explicit, decouples forcing events from solver spans, preserves rejected-trial rollback, and requires hard whole-process water closure. No solver tolerance or Richards policy change is authorized.

## Initial status

- Implemented: existing restricted Hupsel Rutter process only.
- Persisted: this preregistration and the characterization harness are being added on the work branch.
- Tested: not yet.
- Qualified/admitted: no new INT13 claim.
- Blocker: exact B1.11 `MOD_meteo.f90` member must be materialized from its pinned archive authority before selecting legacy versus corrected semantics.
- Recovery point: this branch and `integration/audits/F-MIG431-INT13_PREREGISTRATION.md`.
