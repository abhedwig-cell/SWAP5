# F-MIG431-INT13 Rutter source-window migration

Status: PREREGISTERED / LOCAL PRODUCTION QUALIFICATION PASS / PERSISTED ADMISSION PENDING
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
- The canonical checkout contains the deterministic B1.11 reconstruction tooling and identities, but not the exact B0 distribution archive or reconstructed `MOD_meteo.f90` member. The public Git history located during this work identifies itself as SWAP 4.2.0, not the exact B1.11 authority, so it is not used as the equation oracle. The B1.11 patch chain shows that its only `MOD_meteo.f90` patch changes dynamic-crop meteo loading and does not touch Rutter. This supports, but does not replace, the bounded equation authority already admitted under F-APP05/F-VQ114.
- The repository's B0 import gate is explicitly `PENDING_BINARY_SAFE_IMPORT`; its verified archive identity is SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`. A workspace search found no matching source archive; only unrelated test/reference ZIPs are present.
- No open PR or branch search result identified an existing INT13/Rutter successor at reconciliation. INT13 is therefore available as a provisional identifier.

## Initial falsification target

The current process reports a maximum event timestep when the canopy fills or empties, but also clips the end-of-interval canopy store to capacity. Its output contract must be tested for a longer-than-event call. With full cover, empty storage, capacity 0.1 cm, gross rain 1 cm/day, zero evaporation and a one-day interval, the routine reports all rain as intercepted while publishing only 0.1 cm of storage. Unless the caller splits the forcing interval at the event and sends the post-event rain to the soil, 0.9 cm is unaccounted for. This experiment characterizes the current API; it does not yet establish whether B1.11 has the same event-driving requirement or whether the accepted Hupsel caller satisfies it.

## Follow-up source and ownership inspection (2026-10-04)

- Two attempts to retrieve the pinned historical archive failed before transfer with a network error. The archive itself remains identified by the verified B0 hash in `reference/swap-4.3.1/b0/VERIFICATION_RESULT.md`; no substitute source was used.
- In the current checkout, `maximum_event_timestep_days` is written and validated only by `mod_rutter_interception_process`; no production source under `src/**/*.f90` consumes it. The existing F-APP05 Rutter tests call `evaluate_rutter_interval` directly. F-APP08 tests typed output binding, not the forcing/event driver. Thus this checkout does not demonstrate that a production caller splits the meteorological source window at a canopy event.
- `mod_interception_source_window_runtime` already represents immutable source-window identity and accepted endpoint progress, but contains no canopy-water state. A Rutter composition must trial both (a) Rutter's physical canopy storage and (b) apportioned source-window progress from one accepted snapshot, then publish them together only when the enclosing hydrological transaction accepts. A Richards reject must leave both unchanged. Reusing the runtime by itself would not meet the physical-state transaction invariant.
- This is an event-integration/API limitation in the available legacy process seam. The new corrected reference retains its short-interval flux branches, internally resolves fill/empty events, and closes the mass balance for long source windows. The original admitted `mod_rutter_interception_process` remains byte-identical. This does not establish that the complete historical B1.11 caller failed to split at the event; its call-site body is not present in the checkout.

## Corrected-reference decision and local evidence (2026-10-04)

`integration/audits/F-MIG431-INT13_CORRECTED_REFERENCE.md` records the explicit `LEGACY_B1_11` versus `CORRECTED_RUTTER_REFERENCE` distinction. The falsifying case is an empty, fully covered canopy with `Smax=0.1 cm`, rain `1 cm/day`, zero evaporation and a one-day interval: an unsplit legacy call leaves `0.9 cm` unaccounted; event integration sends `0.9 cm` to throughfall and retains `0.1 cm`, with residual at floating-point roundoff. Capacity loss is explicitly routed from canopy to surface.

`mod_rutter_source_window_processor` composes Rutter canopy state and INT12 accepted source progress into one candidate. The application seam binds this candidate to the admitted dynamic-top and crop/root input contracts, but leaves acceptance to the host transaction. `integration/audits/F-MIG431-INT13_LOCAL_QUALIFICATION.json` records local O0/O2 evidence for conservation, event fill/dry-down, source-window refinements, rejected candidates, restart, record continuation, output composition and existing F-APP05/F-APP08/INT12 preservation.

The candidate is wired through the production bootstrap, FMR physical-state candidate, transaction accept/reject path and restart layout. Local O0/O2 production qualification passes. It remains not canonically admitted: the remote PR and persisted Actions evidence could not be updated because the GitHub proxy is unavailable. The worktree remains based on the previously reconciled canonical head below.

## Required decisions and gates

1. Reconstruct and inspect exact B1.11 Rutter equations, call sites, event ordering, capacity transition, rain/irrigation/snow interactions, canopy-change semantics and mass accounting.
2. Establish independent analytical references for empty/filling/full/drying cases and compare a single source window against event-split and meteorological-record refinements.
3. Select either a source-window Rutter integration whose accepted result is invariant to Richards retry/substep patterns, or record a specific physical/legacy reason it cannot be used.
4. Persist canopy storage and source-window progress atomically; verify reject, retry, restart and detailed-meteorology continuation.
5. Preserve the admitted `SWINTER=0/1/2`, Black and Boesten surfaces in their declared envelopes and fail closed for unsupported combinations.
6. Local O0/O2 physics, mass, source-window, production transaction and restart gates pass. Complete Black/Boesten runtime preservation locally, then run the bounded persisted qualification on the PR before canonical admission.

## Architecture invariants

Affected invariants: 3, 4, 7, 9, 13, 23, 26, 29 and 30. The intended change makes process state explicit, decouples forcing events from solver spans, preserves rejected-trial rollback, and requires hard whole-process water closure. No solver tolerance or Richards policy change is authorized.

## Current status

- Implemented: unchanged admitted Hupsel process, corrected event integrator, source-window/canopy-state trial, typed dynamic-top application, FMR physical continuation, production bootstrap and restart registration.
- Persisted locally on the work branch: corrected-reference decision, local qualification evidence, source/runtime modules and O0/O2 test runner.
- Tested locally: corrected source-window suite and production bootstrap pass O0/O2; INT12-P0/D/E pass O0/O2; F-APP05/Hupsel and F-APP08 binding preservation are retained. Black/Boesten static preservation checks pass; full runtime runners are being completed offline.
- Qualified/admitted: no new INT13 claim.
- Remaining admission gate: complete Black/Boesten runtime preservation, persist qualification and bounded admission on the remote PR, then merge canonically and update the family closure status. GitHub network access is unavailable in this workspace, so no Actions or admission claim is recorded. Exact full B1.11 call-site source remains unavailable; bounded Hupsel/F-VQ114 equation authority and patch-chain evidence support the corrected-reference decision without claiming the historical caller had the same defect.
- Draft review checkpoint: PR #1016, based on canonical `9605fbb1622d96f4691117f66264f13b6dd3a47b`.
- Recovery point: this branch and `integration/audits/F-MIG431-INT13_STATUS.json`.
