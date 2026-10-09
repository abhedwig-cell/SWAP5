# MC-CROP01: meteorological day-start authority and F-KT binding (2026-10-09)

Status: **reconciliation / preregistered contract only**. Not implemented, not tested, not qualified, not admitted. Base canonical `5df74f95a8443cc62152f9df4c317957579af087`.

## Exact historical observations

- B1.11 retained `SWAP/swap.f90` Git blob `831a345db0ba9dc4ef2fdfe09e1bbf011b4027a5`: in day-start loop lines 354-376, `TimeControl(2)` precedes `Meteo(2)` (normal `iCaller/=2`) or `handle_exchange(22)` (external `iCaller=2`); **both precede** `croprotation(2)`.
- Same blob lines 682-696: external exchange assigns `tmn=toswap%tmin`, `tmx=toswap%tmax`, `tav=(tmx+tmn)*0.5d0`, `tavd=(tmx+tav)*0.5d0`. The exact operation order matters for source-identity claims.
- B1.11 retained `SWAP/MOD_cropdevelopment.f90` Git blob `6f587310c7b9e9ba5e79f22d988bddd5feead133`: germination imports `atmosphere_interface:tav` (line 651) and consumes it in temperature sums (lines 755-766).
- The **normal** `MOD_meteo:Meteo(2)` writer is **not** established by the checked-in retained B1.11 subset. The public evolving SWAP `meteoday.f90` is not an exact 4.3.1 oracle. Do not claim its detailed meteorology expression as proved B1.11 semantics.
- `src/crop/mod_crop_tav_day_window.f90` currently accepts caller-declared source, lineage, revision and temperature. It is a *candidate* accumulator, not an owner-issued provenance certificate.
- PPA-WU03 admits a bounded common forcing adapter with resolved fluxes, *not* full historical file/calendar meteorology or its `tav` owner. F-KT accepted hydrothermal snapshots certify soil provenance only.

## Critical temporal correction

Do **not** make day-start germination depend on acceptance of the **end of the same day** F-KT trajectory. That would reverse the historical `Meteo(2) -> croprotation(2)` ordering. Distinguish (1) weather record acquired and certified at day start, (2) certified soil state already committed **before** day-start crop evaluation, and (3) eventual accepted crop-state/event commit under the transaction protocol. Weather record validity and hydraulic interval acceptance are different facts.

## Proposed owning boundary, not yet approved

1. The existing **actual production weather input owner**, not crop candidate code or WOFOST caller data, issues an immutable weather-day token: producer/source identity, day key and calendar, input mode, exact input values/digest, `tav`, write-method identity, forcing epoch and revision. An opaque token copied from user input is **not** authentication. The issuing owner must preserve and validate the underlying values and identity.
2. Weather day-start read is independent of whether a prospective F-KT interval later succeeds or fails. Retried intervals must reuse the *same* authoritative daily record, without double counting or re-importing new weather silently.
3. Crop preflight receives that validated token plus an **already accepted**, owner-certified F-KT soil snapshot with exact lineage, committed revision, instant, B110 grid/parameter identity and heat option. The two time meanings must be explicit; neither may be inferred from the other.
4. The crop-state owner must own state transitions and durable event identifiers. Preflight is read-only. Publication is once-only upon accepted crop transaction, never upon candidate production, trial rejection or replay alone.
5. A restart must reconstruct and verify owner provenance for weather, previous accepted F-KT soil and committed crop event history, rather than minting tokens from snapshots supplied by a caller.
6. This contract does not authorize edits to `src/kernel/`, common `src/runtime/`, meteorological adapters, WOFOST, crop state or crop/root sources until relevant owners and preservation surfaces have been explicitly reconciled.

## Required independent negative matrix before promoting physical events

- Forged token/source ID/digest/mode, stale day or epoch, altered Tmin/Tmax while preserving candidate mean: **reject; no event**.
- Day length, calendar rollover/leap day and local day-start semantics: check against exact B1.11 `MOD_meteo` and `TimeControl`; do not assume F-KT day fractions define meteorological records.
- Gap/overlap/reordered detailed records; mixed weather sources: reject unless the actual owner documents and certifies a source-faithful normalization.
- Trial reject followed by retry, shortened accepted interval, duplicate acceptance, rollback: no double weather record and no duplicate crop event.
- Correct temperature attached to wrong committed soil lineage/revision/instant, or wrong B110 grid/heat: reject without mutation.
- Restart with missing or changed weather provenance, event history, or committed F-KT provenance: fail closed.
- Distinguish SWGERM=0/1/2, SWHEA off/on, prep/sow ordering, crop rotation, harvest, fallow and successor crop; retain existing B19/MICRO/root and mass/restart gates.
- Run locally at O0 and O2 against the actual persisted Fortran postimage, including negative tests; exact-head owner and full F-CI preservation are mandatory before canonical scientific admission.

## Resolution and next action

Recover the **exact** SWAP 4.3.1 `MOD_meteo`/daily writer and detailed weather conventions from the verified official source archive, including the `TimeControl` day boundary. Reconcile with PPA-WU03 current forcing owner and actual F-KT application pathway. Only then implement a narrowly owned weather-day receipt and a cross-owner validation entry point. Keep existing `mod_crop_tav_meteorological_candidate` and `mod_crop_tav_day_window` as untrusted staging logic.

**Claim ceiling:** historical external writer and ordering evidenced; physical meteorological owner certificate, accepted daily TAV coupling, crop lifecycle transitions and event publication all remain OPEN. No Github Actions are required for this documentation checkpoint.
