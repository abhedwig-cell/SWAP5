# F-WOF-EXT01: cross-process single-writer crop commit and V3 native identity, 2026-10-17

## Executed PCSE qualification — PASS

PCSE research PR #9 head `6c484c8adb5b3c2a642b140bdd40dec6b539d65c`; [Actions run 39066720663](https://github.com/abhedwig-cell/pcse/actions/runs/39066720663) **SUCCESS**. The actual PCSE-WOFOST81 crop-state journal is now serialized through a Linux advisory `flock` lock spanning recovery, prior/event/candidate validation, atomic replace and recovery. Tests executed with a realistic day-30 source and detached one-day candidate:
- `EXT01_DURABLE_TWO_PROCESS_COMMIT_RACE_PASS`: two separate Python processes compete to publish the *same* event and candidate, exactly one succeeds; one rejects a stale/duplicate event, and only one event receipt remains.
- `EXT01_DURABLE_CONCURRENT_STALE_WRITER_REJECTED`: two independent concurrent writers in threads, same postcondition.
- `EXT01_DURABLE_CROP_STATE_RECEIPT_ATOMIC_PASS`: injected failure before atomic publication leaves prior authority untouched, while a completed commit persists state and receipt together.
- `EXT01_DURABLE_CROP_JOURNAL_TAMPER_REJECTED`: journal checksum corruption refused.
- `EXT01_UNATTESTED_REAL_SWAP_PROVENANCE_REJECTED`: the actual PCSE transaction worker rejects unsupported real-SWAP provenance claims instead of accepting an arbitrary unverified provenance string.

**Qualification limits:** local Linux cooperative/advisory locks, same filesystem rename, no demonstrated multi-host lock correctness, arbitrary power loss, accepted SWAP5 hydrology lock or two-authority distributed transaction. No production PCSE API.

## SWAP5 physical-source identity and calendar

The accepted window owner in `src/runtime/mod_fmr_wofost_accepted_window_lineage.f90` already has persistent `lineage_id`, `final_revision`, `t0`, `t1`, `actual_root_uptake_integral`, `potential_transpiration_integral`. The rooted physical test now emits them via `F_WOF_EXT01_ACCEPTED_IDENTITY` in a **research-only test log**, not a new numerical model. Its output observed in run 39065789383 included `630101 192 2.000000E+00 3.000000E+00` with the formerly verified accepted uptake `1.0370706377336118E-03`. V2 exporter initially failed because its raw identity regex accidentally matched a literal escaped backslash, not whitespace; commit `cd7dacdcf5afe0bb3ed2c9d88a278b256e3e235b` corrects it.

The same Fortran physical test reads a Gregorian daily weather series `1999-01-(20+d)`, and defines its epoch as 1999-01-20. Therefore native accepted interval [2,3] ends on **1999-01-23**; it does **not** become the independent PCSE spring barley 2010 fixture date. V3 witness exporter `cae5039d5928ba529a3aefc62d1d162d4560fde1` records the native 1999 epoch and explicitly derived native window-end day, while retaining `calendar_date=null` for the PCSE matched day and `unit_conversion_to_cm=null` pending a positively qualified unit and data mapping. The V3 import guard `86e6c0261863fd2006512da01fa50186eabf2bcc` rejects forged window-end dates or synthetic PCSE alignment, and still refuses all witness-only import for production crop execution.

At the time of this scientific note, the V3 physical-export and import-gate jobs were queued; **do not claim they passed** before their completed logs are checked.

## Decision

**PASS** real PCSE crop journal concurrency and rejection of false physical provenance. **UNQUALIFIED** true same-day SWAP5 hydrological acceptance to PCSE, native-to-PCSE unit and meteorological mapping, and distributed cross-authority atomic commit. Continue only on research PRs SWAP5 #1279 and PCSE #9. SWAP5 canonical and its admitted WOFOST81 crop equations unchanged.
