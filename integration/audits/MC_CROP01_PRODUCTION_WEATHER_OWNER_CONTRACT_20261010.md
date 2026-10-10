# MC-CROP01: production meteorological ownership seam (2026-10-10)

Canonical evidence baseline: `96655ac0d8e60cbd1c64093403e596376ae56d01`.

This is an implementation admission gate, **not** an admitted meteorological producer or an acceptance certificate.

## Actual inspected owners and blob identities

| Surface | Blob | Current authority |
| --- | --- | --- |
| `src/runtime/mod_fmr_production_application_bootstrap.f90` | `42a892e3b8c61993e0b3d14c2a909b5a8527da59` | Executes already-resolved `fmr_b110_physical_forcing_t` intervals; no daily Tmin, Tmax, TAV or meteorological source field |
| `src/adapter/mod_ppa_wu03_common_forcing_adapter.f90` | `30231b4c08c900da406a388d3a54aca600f5bf47` | Creates interval-effective top/ET forcing, not meteorological day provenance |
| `src/crop/mod_crop_weather_day_owner.f90` | `f2b5661f6c3746e64e1791fd7ae45b997d0b5b0a` | Self-registered source/epoch/day/revision with local TAV. Caller may initialize it; cannot attest meteorological source |
| `src/runtime/mod_fmr_crop_weather_day_preflight.f90` | `8a99fb56d1b88d47989560c526d99a3888c841dd` | Read-only staged daystart coupling between local TAV and owner-certified F-KT soil state |
| `src/runtime/mod_fmr_crop_certified_daily_preflight.f90` | `3c6242ee6e052478eb107600c21a7d30858a76c7` | Owner-certified pressure-head/soil-temperature; external daily air value is not source-authenticated |

## Historical sequence and prohibited shortcut

The retained B1.11 `SWAP/swap.f90` enters normal `Meteo(2)` or external `handle_exchange(22)` **before** crop rotation / daystart crop work. The external route computes `tav=(tmx+tmn)*0.5d0`. The normal internal `Meteo(2)` writer and detailed-day semantics still require exact source proof. Never substitute a candidate equation for that missing normal-route authority.

Do **not** manufacture a weather certificate from caller-assigned source IDs, PPA-WU03 interval forcing, or an F-KT committed soil receipt. None proves an authentic daily weather input was consumed. Do **not** require the accepted hydraulic state at the *end of the same new day* to run daystart crop decisions. Only the previously accepted F-KT state may be consulted.

## Required source-owner work unit

1. At the trusted actual meteorological ingestion seam, capture the already parsed raw daily values, source immutable identity, epoch, day and calendar mapping. The same source must issue records to physical forcing and crop. No second independent `tav` caller argument.
2. Decide ordinary daily vs detailed meteorology **from the source route**, not guessed from WOFOST or unrelated effective interval forcing. Prove arithmetic identity for each admitted route.
3. Emit a read-only daystart weather record *only after the producer has accepted the input for that exact day*. Bind its receipt to the exact source/epoch/day/value and provenance of the physical interval forcing when they share an input; do not infer an independent match by time alone.
4. Define transactional retries: failure leaves the current accepted weather day and crop unchanged; an identical retry cannot double-increment revision or reapply the crop update; conflicting same-day input is rejected. Source change requires a separately authorized epoch transition.
5. Include daily weather state and any pending read/consumed marker in the **same trusted restart ownership story** as crop lifecycle. Reconstructed caller-controlled source ID alone is not a trusted restart attestation.
6. Wire this producer-owned receipt into `mod_fmr_crop_weather_day_preflight` only once source-authenticated, and then into the crop-state/event transaction using the existing accepted F-KT lineage and committed interval/event owners. Do not create a parallel F-KT commit authority.

## Mandatory test gate before physical event admission

- Normal `Meteo(2)` and external `handle_exchange(22)` each with independently proven historical oracle.
- Exact-day source change, epoch change, stale revision, duplicate day (same and different values), absent day, skipped day, calendar-boundary and detailed/daily route switch.
- Failure atomicity under rejected/rolled-back F-KT trial; weather prepared but not physically committed; accepted prior-day soil at daystart.
- Serialized and trusted-restart recovery, and replay after crash between weather acceptance and crop publication, proving exactly-once physical crop event.
- Genuine driver with live producer, crop preflight and F-KT accepted state, O0/O2, B19/MICRO preservation, exact-head F-CI.
- New production code needs its own workstream/reviewer reconciliation because the bootstrap and PPA-WU03 surfaces are shared with other concurrent workstreams.

## Current ceiling

Existing `weather_day_owner_t` and its bridge are **staging-only**; a local `WEATHER_DAY_OK` or `CROP_WEATHER_PREFLIGHT_OK` must never be surfaced as a physical weather-provenance or crop-publication certificate. The heat-off `SWSOW=0` B1.11 correction remains admitted independently.

No production implementation, tests, crop acceptance or master-coverage promotion is claimed by this contract.
