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
- Git inspection confirmed that the source is findable there: `SWAP-model/swap-4.2.0` contains `src/meteoday.f90` at commit `c30e5e4cd3a7427246b5206c15ad6960897d18d3`, blob `90c3a9aae0035b6af3620d006f2224222bae80a8`, SHA-256 `f813b41eec87e076af272e27369cde8539de471812a6f23f3c5b651f67ce1fed`. This authentic Git source is the equation oracle used for `ruttervw/msw1eic`; its version limitation is explicit because it is 4.2.0, not the exact B1.11 member. B1.11 authority identifies the member hash and patch lineage; its sole `MOD_meteo.f90` patch changes dynamic-crop meteo loading and does not touch Rutter. No 4.3.1/B1.11 source repository or matching branch was found in the `SWAP-model` organization. The version gap therefore limits byte-identity claims, but the available unchanged Rutter lineage plus the authenticated Git equations support the bounded analytic reference.
- The repository's B0 import gate is explicitly `PENDING_BINARY_SAFE_IMPORT`; its verified archive identity is SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`. A workspace search found no matching source archive; only unrelated test/reference ZIPs are present.
- No open PR or branch search result identified an existing INT13/Rutter successor at reconciliation. INT13 is therefore available as a provisional identifier.

## Initial falsification target

The bounded SWAP5 `evaluate_rutter_interval` API exposes a fill-event endpoint and clips its candidate store. A falsifier with empty storage, capacity 0.1 cm, rain 1 cm/day, zero evaporation and a one-day call returns no throughfall and only 0.1 cm storage. This is a limitation of that short-interval API for source-window ownership. Git inspection of SWAP 4.2.0 `ruttervw`/`msw1eic` found an internal analytical fill time (`tcap`) and a minimum relative canopy-evaporation factor (`fimin`); the full reference accounts for post-fill rainfall inside the interval. The exact B1.11 file is not materialized, so this predecessor source is used with its version limit stated explicitly; the falsifier is not attributed to B1.11.

## Follow-up source and ownership inspection (2026-10-04)

- Two attempts to retrieve the pinned historical archive failed before transfer with a network error. The archive itself remains identified by the verified B0 hash in `reference/swap-4.3.1/b0/VERIFICATION_RESULT.md`; no substitute source was used.
- In the current checkout, `maximum_event_timestep_days` is written and validated only by `mod_rutter_interception_process`; no production source under `src/**/*.f90` consumes it. The existing F-APP05 Rutter tests call `evaluate_rutter_interval` directly. F-APP08 tests typed output binding, not the forcing/event driver. Thus this checkout does not demonstrate that a production caller splits the meteorological source window at a canopy event.
- `mod_interception_source_window_runtime` already represents immutable source-window identity and accepted endpoint progress, but contains no canopy-water state. A Rutter composition must trial both (a) Rutter's physical canopy storage and (b) apportioned source-window progress from one accepted snapshot, then publish them together only when the enclosing hydrological transaction accepts. A Richards reject must leave both unchanged. Reusing the runtime by itself would not meet the physical-state transaction invariant.
- The initial event-subdivision implementation was insufficient because it omitted `fimin` and did not reproduce the analytical storage ODE. It has now been replaced by the analytic reservoir reference reconstructed from Git; the admitted short-interval `mod_rutter_interception_process` remains byte-identical. The corrected reference internally solves fill time and closes source-window mass.

## Corrected-reference decision and local evidence (2026-10-04)

`integration/audits/F-MIG431-INT13_CORRECTED_REFERENCE.md` records the Git-derived analytic Rutter equation and the limits of its version authority. The zero-evaporation capacity case returns `0.9 cm` throughfall and `0.1 cm` storage with roundoff closure. The old SWAP5 one-call API falsifier is explicitly not attributed to B1.11. The source processor requires `fimin`, rejects inconsistent non-zero capacity with no canopy cover, and preserves the source zero-capacity vegetation-death branch. Positive-capacity decreases release excess storage to the surface.

`mod_rutter_source_window_processor` composes Rutter canopy state and INT12 accepted source progress into one candidate. The application seam binds this candidate to the admitted dynamic-top and crop/root input contracts, but leaves acceptance to the host transaction. `integration/audits/F-MIG431-INT13_LOCAL_QUALIFICATION.json` records local O0/O2 evidence for conservation, event fill/dry-down, source-window refinements, rejected candidates, restart, record continuation, output composition and existing F-APP05/F-APP08/INT12 preservation.

The candidate is wired through the production bootstrap, FMR physical-state candidate, transaction accept/reject path and restart layout. Local O0/O2 source-window and production qualification pass. PR #1016 at `344dff1176e0bde049f0de8d713fd76e1a761dd9` contains the earlier source-window implementation; the analytic `fimin` correction and qualification workflow are now in the local candidate and must be persisted and run. INT12-P0/D/E and PPA-WU01 Actions passed on the earlier candidate. Canonical F-CI run `37224481353` completed with a failure in unrelated `current-restricted-canonical-preservation`; INT13-specific evidence is still pending.

## Required decisions and gates

1. Compare authenticated SWAP 4.2.0 Git Rutter equations with the cryptographic B1.11 member identity and patch chain; retain the explicit source-version limit, then qualify call ordering, capacity transition, supported rain inputs and mass accounting.
2. Establish independent analytical references for empty/filling/full/drying cases and compare a single source window against event-split and meteorological-record refinements.
3. Select either a source-window Rutter integration whose accepted result is invariant to Richards retry/substep patterns, or record a specific physical/legacy reason it cannot be used.
4. Persist canopy storage and source-window progress atomically; verify reject, retry, restart and detailed-meteorology continuation.
5. Preserve the admitted `SWINTER=0/1/2`, Black and Boesten surfaces in their declared envelopes and fail closed for unsupported combinations.
6. Local O0/O2 physics, mass, source-window, production transaction, restart and Black/Boesten runtime-preservation gates pass. Review persisted PR results and ensure INT13-specific physics/transaction evidence is represented before canonical admission.

## Architecture invariants

Affected invariants: 3, 4, 7, 9, 13, 23, 26, 29 and 30. The intended change makes process state explicit, decouples forcing events from solver spans, preserves rejected-trial rollback, and requires hard whole-process water closure. No solver tolerance or Richards policy change is authorized.

## Current status

- Implemented: unchanged admitted Hupsel process, corrected event integrator, source-window/canopy-state trial, typed dynamic-top application, FMR physical continuation, production bootstrap and restart registration.
- Persisted locally on the work branch: corrected-reference decision, local qualification evidence, source/runtime modules and O0/O2 test runner.
- Tested locally: corrected source-window suite and production bootstrap pass O0/O2; INT12-P0/D/E pass O0/O2; F-APP05/Hupsel and F-APP08 binding preservation are retained. Black/Boesten runtime and preservation runners pass O0/O2 through temporary offline harness copies.
- Qualified/admitted: no new INT13 claim.
- Remaining admission gate: persist the corrected analytic candidate to PR #1016 and require the new INT13 workflow's physics and production jobs to pass. Exact full B1.11 call-site source remains unavailable, so preserve the recorded source-version limit; the authenticated Git equation source and non-Rutter B1.11 patch lineage support this bounded decision without claiming byte identity or attributing the SWAP5 short-interval API defect to B1.11. No merge or admission claim is recorded.
- Draft review checkpoint: PR #1016, based on canonical `9605fbb1622d96f4691117f66264f13b6dd3a47b`.
- Recovery point: this branch and `integration/audits/F-MIG431-INT13_STATUS.json`.
