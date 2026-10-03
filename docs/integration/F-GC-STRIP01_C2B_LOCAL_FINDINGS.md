# F-GC-STRIP01 C2B local continuation

Date: 2026-10-03. Status: corrected-sign rainfall publishes in a bounded research fixture; full physical coupling remains unqualified.

The objective remains a working 50-cell, 50 m SWAP–MODFLOW6 strip: one SWAP column per 1 m cell, a left drain, right and bottom no-flow, SWAP-owned soil water storage, MODFLOW groundwater state, closed mass accounting, measurable groundwater response, and committed restart/replay. This branch is research only; canonical admission is not claimed.

## Critical flux-sign correction

The canonical serialized reference backend `src/runtime/mod_fmr_serialized_reference_backend.f90`, routine `account_external_fluxes`, accounts `total_in = max(0,-external_top_flux)` and `total_out = max(0,external_top_flux)`. Therefore positive `top_flux` is outward from the soil and negative `top_flux` is inward. Rain/infiltration is represented by a negative flux.

This corrects the classification of prior local probes: the fixed-flux trials at +0.1 cm/day, their duration/rate sweeps, temporal-history seed discriminator and full-window attempts tested outward flux, not rain. Their rejection results remain useful as outward-flux/temporal-history evidence, but none qualifies rainfall. The earlier prose that called +0.1 cm/day rainfall was wrong. The dynamic B1.11 route is a different route and remains excluded before solver admission when combined with `bottom_mode=5`.

## Correct-sign rainfall results

A true inward fixed flux of -0.1 cm/day was tested with the native MODFLOW6 engine and 50 real SWAP columns. The ordinary 0.001-day window rejects in the first SWAP corrector, both without a derivative seed and with the experimental seed. Committed state is preserved; MODFLOW prepares and solves but does not finalize its time step.

A single 1e-5-day micro-window publishes all 50 columns. Input is 5.0e-7 m³, SWAP storage increases by approximately 5.0e-7 m³, drain outflow is zero, and the mass residual is 1.2624e-15 m³.

The same 0.001-day elapsed forcing was then split into 100 windows of 1e-5 day. All 100 publish; each column reaches revision 100 and interface-ledger count 100. MODFLOW prepare, solve, finalize-solve and finalize-time-step each run 100 times. Total input is 5.0e-5 m³, SWAP storage change is 4.99999999945544e-5 m³, drain outflow is zero, and cumulative signed mass residual is 5.44560785218284e-15 m³; maximum absolute per-window residual is 5.843048628287003e-15 m³. Two fresh runs have byte-identical 1,091,110-byte result JSON (SHA-256 `2c11da80b89e377e4b52064bd38bf06643e8ee706104b31ae46175e2a5e17cac`). A compact aggregate record is stored at `integration/f-gc/strip01/results/c2b-local-20261003/C2_correct_sign_rain_micro100_summary.json`.

This is bounded publication and mass-balance evidence only. The derivative seed was experimentally captured and injected by the research fixture; it is not an admitted runtime route. All MODFLOW heads remain -1 m, and no measurable head, lateral-flow, bottom-interface or drain response occurs during these 86.4 seconds. Thus the coupled strip benchmark is not yet working in the intended hydrologic sense.

## Historical tests and other blockers

The isolated onset values previously reported (including Binf=0.867884 cm at 0.001 day against the 1e-5 cm limit, and seed reduction to 0.00187113 cm) came from positive +0.1 cm/day outward flux. They must not be interpreted as rainfall onset behavior. The corrected-sign 0.001-day rainfall window also rejects at the corrector, so the forcing-boundary temporal-history problem remains, now with a properly signed test.

The dynamic Black B1.11 surface-balance variant with `bottom_mode=5` still returns `KERNEL_STATUS_NOT_ADMITTED=101` before solver execution. No production source, mass gate, retry limit or canonical branch was changed. The 144 compiled `src/` blobs match the pinned canonical source tree `e3bfcdca00ba89cfeea529cf9b648dcc803483ab`.

The old zero-flux equilibrium C2a still passes. In corrected-sign C2b, the normal 0.001-day step rejects without publication and preserves accepted state. Splitting this forcing into experimental micro-windows accepts and balances water, but does not establish measurable groundwater exchange or drainage. Restart, longer forcing, Hupsel, lateral/drain response, production integration and canonical admission all remain open.

## Next work

Resolve how accepted SWAP temporal-history authority is updated when surface forcing changes at a coupling-window boundary. Keep the frozen 1e-5 cm error gate and 1e-8 day minimum. Qualify the derivative or another onset treatment as an ordinary runtime path, then demonstrate measurable MODFLOW head/lateral/drain response and nonzero interface exchange while closing the full-domain balance. Extend duration, test rejection/replay/restart, and only then advance to Hupsel. Separately qualify dynamic B1.11 precipitation with `bottom_mode=5` or establish a narrower imposed-infiltration contract.

## Source-bound reproduction record

The latest fixture build is `build-c2-micro-series`; its manifest records 144 production `src/` blobs bound to the pinned canonical tree. The compact evidence summary records the exact native run hash and byte-identical replay. The 1.1 MB full run files were retained locally for analysis; the repository receives the compact summary. No GitHub Actions run was needed for these local native tests.
