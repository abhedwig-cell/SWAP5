# F-WOF-EXT01: accepted SWAP5 water-flux units and time-phase source trace (2026-10-17)

## Code-path evidence

The physical production application connects its rooted-water demand to `common%reference_et_demand%potential_transpiration_cm_per_day` in `src/runtime/mod_fmr_production_application_bootstrap.f90`. The ET demand provider derives potential transpiration from reference ET in mm/day with a factor 0.1 and publishes a named cm/day field. The physical root-input evaluator returns `root_fluxes%root_extraction_sink`, and the application defines `qrot=sum(effective(1)%root_extraction_sink)` and `ptra=root_input%potential_transpiration`. The same `qrot,ptra` pair is passed to `accumulate_wofost_trial_process_rate(trial,t0,t1,...)`, which computes `actual_add=actual_root_uptake_rate*dt` and `potential_add=potential_transpiration_rate*dt`. The event receipt persists accumulated integrals over accepted intervals, not rates for an unaccepted hydrological trial.

This path is now guarded by `tests/fwof/ext01/test_accepted_rate_unit_trace.py`, introduced at SWAP5 research commit `089e4c8950910bdf0ee6de23e96541b4416d6a8a` and added to the focused contract CI in `1ed527cbe2e6cd28c584d0fd4b06d48ef532a219`, Actions run `39071740080`. **EXECUTED PASS**: [SWAP5 Actions 39071740080](https://github.com/abhedwig-cell/SWAP5/actions/runs/39071740080) completed SUCCESS (native Fortran and protocol-probe); source-unit trace markers `EXT01_SWAP5_ACCEPTED_RATE_INTEGRAL_SOURCE_TRACE_PASS` and `EXT01_SOURCE_TRACE_NOT_POSITIVE_PCSE_COUPLING` observed.

## What the trace does and does not prove

It documents a consistent *intended* depth-unit path and one-day integration, and will fail if these source expressions drift. This is stronger than guessing a conversion factor solely from a printed number, but weaker than an independent dimensional/numerical audit of the actual root sink and soil mass-balance source. No new scientific observation has been made by the static trace. The actual V3 witnessed native quantity remains `0.0010370706377336118`, source 1999-01-23, lineage 630101, final revision 192, accepted interval [2,3]. Independent PCSE barley uses an unrelated 2010 crop/weather calendar.

The cross-repository exact-byte negative import check already PASS in PCSE run `39069402664`, and deliberately numeric-only (synthetic assumed cm/day) actual PCSE worker plus durable journal transport PASS in `39070866439` and `39070913808`. These transport checks must not be described as a full physical SWAP–PCSE coupled day.

## Next scientific admission block

1. Cross-check root sink actual cm/day **and sign** against the accepted SWAP5 soil water storage/root uptake mass diagnostics, including stress zeros and nonunit day durations.
2. Construct a genuinely equal-dated and equal-forced test (PCSE 1999 rooted-weather driver matched to the SWAP physical experiment, or a SWAP physical experiment under the qualified PCSE 2010 barley weather) with crop parameter provenance and admissible units.
3. Bind the actual accepted SWAP hydrological event identity and original weather checksum to the external crop event; require the recipient to validate that authority, not accept caller-supplied synthetic `hydro_provenance`.
4. Qualify crash/retry after SWAP accepted hydrology but before PCSE commit and after PCSE commit, including mass conservation and a single event per day across both owners.

**Conditional research GO; production NO-GO.** No change to canonical WOFOST81 physics.

## Zero-potential accepted crop day: actual PCSE process and durable journal

The original worker rejected `p==0` even when `a==0`; this contradicted accepted zero-demand days in the SWAP5 receipt domain. PCSE research commit `f5c8676c0e14cefc2a9a24a6faa5976c42697833` adds a guarded `p==0,a==0,RFTRA==1` branch, with refusal for `p==0,a==0,RFTRA==0` or any nonzero actual uptake. [PCSE Actions run 39071950283](https://github.com/abhedwig-cell/pcse/actions/runs/39071950283) completed SUCCESS with `EXT01_REAL_PCSE_ZERO_POTENTIAL_DAY_PASS`: actual isolated PCSE model accepts and commits one such day without spurious stress.

PCSE research commit `10c712ad2b2e5c4322a120169859b221e3ef827e` tests a zero-demand day through the durable PCSE state/event journal: prepared candidate does not change persisted prior, injected failure before replace preserves prior, eventual commit restores correct `TRA=0,TRAMX=0,RFTRA=1` and one receipt after reopen. [PCSE Actions run 39072019895](https://github.com/abhedwig-cell/pcse/actions/runs/39072019895) completed SUCCESS and logged `EXT01_ZERO_DEMAND_DURABLE_RESTART_PASS`. This is a bounded software and state-transition qualification; no accepted real SWAP5 same-day calendar/mass coupling is implied.
