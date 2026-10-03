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

## Seed-free gradual-forcing experiment

To separate injected derivative seeding from accepted temporal history, a research-only runner starts from zero seed and raises correctly signed inward top flux geometrically. With 1e-5-day windows, a 1.005 multiplier and a cap of 0.001 cm/day, all 2,000 windows publish. The rate reaches its cap at window 925 and remains constant for the remaining 1,075 windows. All 50 columns reach revision and interface-ledger count 2,000; native MODFLOW prepares, solves, finalizes solve and finalizes time step exactly 2,000 times. A fresh-process replay is byte-identical.

Total input is 6.373323681432751e-6 m³, SWAP storage increases by 6.373323650166185e-6 m³, drain outflow is zero and cumulative signed mass residual is 3.126656576294253e-14 m³ (maximum absolute single-window residual 1.2742648566547818e-14 m³). All groundwater heads remain -1 m. The per-window forcing, input, storage, drain and residual record is persisted at `integration/f-gc/strip01/results/c2b-local-20261003/C2_correct_sign_seed_free_ramp_2000.csv.gz`; the metadata and replay hashes are in the adjacent JSON summary.

This confirms that accepted history can evolve from an unseeded origin under a very gradual forcing ramp, and that the accepted low forcing can be held for 1,075 windows. The cap is 0.001 cm/day (0.01 mm/day), 100 times below the registered 1 mm/day rain. A separate same-factor ramp toward 0.1 cm/day publishes 999 windows and rejects its next increase at about 0.001458 cm/day. Thus the slow ramp does not reach the target forcing. The accepted rainfall volume is also too small to produce measurable groundwater or drain response. This is a temporal-history diagnostic, not benchmark qualification.

### Finer zero-seed ramp boundary (factor 1.001)

A longer zero-seed run with 5,000 requested windows, 1e-5-day windows and a 1.001 forcing multiplier published 2,984 consecutive windows, then rejected the next corrector transaction. The last accepted inward flux was 0.00019717557719079688 cm/day; the rejected increase was 0.00019737275276798767 cm/day at t=0.02984 day. Every accepted window incremented all 50 column revisions and interface ledgers once. The rejected window preserved the pre-window profile hash; MODFLOW prepared and solved that window but did not finalize solve or time step.

Across the published segment, input was 9.368637638400416e-7 m³, SWAP storage rose by 9.368636852968848e-7 m³, and cumulative signed mass residual was 7.854315674104579e-14 m³. Drain flow remained zero and all MODFLOW heads remained -1 m. The rejected window added no committed storage; its attempted input is not counted as accepted mass. These figures confirm a reproducible forcing boundary, not a functioning hydrologic strip.

After rejection, a separate one-column diagnostic from the same committed origin accepted an isolated dt=1e-6-day trial at the rejected flux: temporal bound 8.640709e-7 cm versus the unchanged 1e-5 cm budget (normalized 0.0864). The ordinary dt=1e-5-day diagnostic rejected. This diagnostic does not run or validate a complete 50-column MODFLOW coupling window at the smaller timestep. The setter limitation was resolved with a separate fixture-only diagnostic API that passes `top_flux` directly into a discarded trial, without changing `base_forcing` or any registered context. Across that accepted-origin probe, zero inward flux and 0.001, 0.00145 and 0.1 cm/day failed at dt=1e-5 day; the rejected increment passed at dt=5e-6 and 1e-6 day; and 0.0002 cm/day passed at all five tested durations from 1e-5 to 1e-6 day. This non-monotone one-column pattern does not establish the cause of the full coupling rejection or prove that a smaller coupled MODFLOW window would publish. The complete 2,985-window sequence including probes replayed byte-identically (SHA-256 `62ae5113f445f62c3be9404c0e5a193383846dbcf7d7d03499795b9bbf6bc7f3`), and the rejected-origin state hash was unchanged. Compact probe results are at `integration/f-gc/strip01/results/c2b-local-20261003/C2_correct_sign_seed_free_forcing_diagnostic_sweep.json`. The fixture guard remains intact.

The research fixture context capacity was raised from 256 to 2,048 windows to run this local sequence; no production source, temporal budget, retry limit or mass gate changed.

### Full coupled window halved to 5e-6 day

To check whether the one-column timestep sensitivity survives the actual coupling service, a fresh zero-seed sequence used 5e-6-day windows, 50 real SWAP columns, 50 native MODFLOW6 cells and the same 1.001 geometric forcing ramp. It published 5,231 consecutive full coupling windows, then rejected the next SWAP corrector at t=0.026155 day. The last accepted inward flux was 0.0018630530299668805 cm/day; the rejected increase was 0.0018649160829968473 cm/day. This is about 9.45 times the last accepted rate in the 1e-5-day sequence. The rejected profile hash remained unchanged.

All columns reached revision and interface-ledger count 5,231. MODFLOW prepared and solved 5,232 windows and finalized 5,231, with no finalization for the rejected step. Published rainfall input was 4.6372902074926295e-6 m³, SWAP storage rose by 4.637290075493183e-6 m³, cumulative signed residual was 1.3199944578962113e-13 m³, and the maximum absolute single-window residual was 1.4473316604800114e-14 m³. Every head remained -1 m; drain volume remained zero. A fresh-process replay was byte-identical (SHA-256 `9f5dca582c1ca4d58b3d4347bf65b4987311eb69827942e71739a803a51e35c8`). Summary: `integration/f-gc/strip01/results/c2b-local-20261003/C2_correct_sign_seed_free_coupled_dt5e6_6000_summary.json`.

Halving the full coupling window materially raises the forcing level reached before rejection, but the accepted 0.0186 mm/day remains about 54 times below the 1 mm/day target. This is a useful full-path timestep-sensitivity result, not a working hydrologic strip benchmark. Production sources and frozen temporal/mass gates were not changed.

A further full SWAP–MODFLOW6 run used 2.5e-6-day windows and the same zero-seed, factor-1.001 ramp. It published 6,120 complete coupled windows, reaching 0.004530228375081027 cm/day; the next increase to 0.004534758603456108 cm/day was rejected by the SWAP corrector at t=0.0153 day. Fresh-process replay was byte-identical (SHA-256 `06ffcd7f24e5c7345b7928c6ec7dc6b3571055529ba2f7c912978f41cb7a1547`). Across published windows, input was 5.655948254320757e-6 m³, SWAP storage rose by 5.655948022820212e-6 m³, and signed residual was 2.3150054570069553e-13 m³. All 50 heads remained -1 m, drain flow remained zero, and the rejected state hash was unchanged. Summary: `integration/f-gc/strip01/results/c2b-local-20261003/C2_correct_sign_seed_free_coupled_dt2p5e6_15000_summary.json`.

Across 1e-5, 5e-6 and 2.5e-6-day windows, each factor-1.001 run reaches a higher rate before its next rejection, but even the shortest tested window stops at 0.0453 mm/day, about 22 times below the 1 mm/day target. This trend is measured only at three durations; do not extrapolate it as a proven timestep law. There is still no measurable groundwater response, so these runs do not qualify the strip model.

### Failure mechanism: coupling tolerance first, SWAP progress limit second

A 1e-6-day full-coupling sequence using the runner's flux residual tolerance of 1e-15 m/s stopped at its third window with `max-coupling-iterations` after 40 MODFLOW solves. The largest absolute flux residual was 1.3934476184905804e-15 m/s, only 39.3% above the configured threshold. State was preserved. This was a coupling stopping criterion, not a SWAP failure.

A research sensitivity run changed only that coupling residual tolerance to 2e-15 m/s. The initial blocker disappeared: 15,239 complete windows published, then the next window failed at `swap-corrector` at 0.004425503442725441 cm/day. It was not a mass-balance rejection. On the exact rejected origin, a discarded one-column trial at the last accepted flux (0.004423734479498845 cm/day) completed at dt=1e-6 day with 6 accepted substeps and 10 solver rejections. At the next 0.04% forcing increase, the dt=1e-6 trial completed only 3 substeps, then recorded 16 solver rejections and zero temporal rejections before returning transaction failure. This points to loss of Richards-solver progress within the substep/retry policy at that forcing and timestep. At other tested durations and nearby rates the diagnostic results vary, so it is not a simple monotone rain-rate threshold.

Thus there are two sequential blockers: the overly tight experimental MODFLOW-SWAP flux tolerance can prevent closure even when residuals are around 1e-15 m/s; once that is relaxed slightly for diagnosis, the SWAP interval transaction eventually exhausts solver progress near 0.0044 cm/day. The user-facing service reports only `swap-corrector` and hides the participant index and detailed transaction failure from the full 50-column call. A fixture-only diagnostic API gives the cause for a representative column, not per-column provenance. No production tolerance or retry gate was changed. Compact evidence: `integration/f-gc/strip01/results/c2b-local-20261003/C2_correct_sign_coupling_tolerance_vs_swap_failure_diagnosis.json`.




## Historical tests and other blockers

The isolated onset values previously reported (including Binf=0.867884 cm at 0.001 day against the 1e-5 cm limit, and seed reduction to 0.00187113 cm) came from positive +0.1 cm/day outward flux. They must not be interpreted as rainfall onset behavior. The corrected-sign 0.001-day rainfall window also rejects at the corrector, so the forcing-boundary temporal-history problem remains, now with a properly signed test.

The dynamic Black B1.11 surface-balance variant with `bottom_mode=5` still returns `KERNEL_STATUS_NOT_ADMITTED=101` before solver execution. No production source, mass gate, retry limit or canonical branch was changed. The 144 compiled `src/` blobs match the pinned canonical source tree `e3bfcdca00ba89cfeea529cf9b648dcc803483ab`.

The old zero-flux equilibrium C2a still passes. In corrected-sign C2b, the normal 0.001-day step rejects without publication and preserves accepted state. Splitting this forcing into experimental micro-windows accepts and balances water, but does not establish measurable groundwater exchange or drainage. Restart, longer forcing, Hupsel, lateral/drain response, production integration and canonical admission all remain open.

## Next work

Next, extend the full-coupling timestep sensitivity test from a reproducible origin: the 5e-6-day run reaches 9.45 times the accepted forcing of the 1e-5-day run, but still rejects well below the target. Map whether a stable combination of window duration and forcing ramp can reach physically meaningful rainfall without crossing the frozen temporal and mass gates. Do not infer coupled recovery from the column probes. Then qualify an onset treatment as an ordinary runtime path and demonstrate measurable MODFLOW head/lateral/drain response and nonzero interface exchange while closing the full-domain balance. Extend duration, test rejection/replay/restart, and only then advance to Hupsel. Separately qualify dynamic B1.11 precipitation with `bottom_mode=5` or establish a narrower imposed-infiltration contract.

## Source-bound reproduction record

The latest fixture build is `build-c2-micro-series`; its manifest records 144 production `src/` blobs bound to the pinned canonical tree. The compact evidence summary records the exact native run hash and byte-identical replay. The 1.1 MB full run files were retained locally for analysis; the repository receives the compact summary. No GitHub Actions run was needed for these local native tests.
