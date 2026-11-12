# F-WOF-EXT01 real PCSE direct crop continuation without replay (2026-10-17)

**Research-only bounded direct-restart PASS. No production or canonical admission.**

## Source and executed evidence

- PCSE research PR #9, pinned commit `948c5d8d98a19ec92f28c533fc2491d62b5d4f10`.
- [Targeted GitHub Actions 39062036608](https://github.com/abhedwig-cell/pcse/actions/runs/39062036608), job `117481800431`: completed SUCCESS.
- Executable implementation: `pcse/tests/test_wofost81_ext01_direct_state_restore.py`; versioned `F-WOF-EXT01/DIRECT-RESTART-EXPERIMENT/2` JSON experimental state packet.
- Actual PCSE `Spring_barley_301` crop-only external-ET engine, same pinned input sources and no PCSE-owned soil water. Capture state after 10, 30 or 45 model days, end first worker process, start a new Python process/PCSE Engine at initial construction state, apply saved crop-component states and rates, nested crop-N demand and uptake, published kiosk state, current timer/date and output history, then execute **only the remaining** 50, 30 or 15 daily transitions. No historic crop simulation is replayed during restore. The result is compared against a separate uninterrupted 60-transition / 61-observation reference and bounded internal crop leaf-state projection.

Recorded markers from exact successful run:
- `EXT01_DIRECT_SEPARATE_PROCESS_RESTART_PASS 10 61`
- `EXT01_DIRECT_SEPARATE_PROCESS_RESTART_PASS 30 61`
- `EXT01_DIRECT_SEPARATE_PROCESS_RESTART_PASS 45 61`
- `EXT01_DIRECT_RESTART_SPLIT_EQUAL 10 61`, `30 61`, `45 61`
- `EXT01_DIRECT_RESTART_DAY10_EQUAL 61`
- `EXT01_DIRECT_RESTART_FOREIGN_STATE_REJECTED`

This supersedes earlier *research-stage* early-day restart failures, which identified omitted intermediate state and kiosk publications; it does not supersede the original production source qualification.

## Validated scope versus remaining unknowns

**Tested:** real new-process direct continuation without replay; exact bounded output trajectory and selected internal leaf-state fields at three split points; rejection of unknown schema and a foreign kiosk variable; no change to SWAP5 admitted source.

**NOT tested:** a complete source-stable, cross-version, signed/checksummed state format; exact reload for all calendars and multi-crop rotations; all latent/private PCSE objects or dispatcher callback state; unbounded event histories; actual SWAP5 accepted hydrological day events; atomic cross-process crop commit, rejected candidate rollback, worker failure at a transaction boundary, per-instance isolation at 50/500 columns, and full performance/operational recovery guarantees.

**Important implementation qualification:** this is an **experimental adaptor** that mutates trait variables, restores currently published kiosk values, and uses a specific PCSE version's engine internals. It must not become a public production API until an owned codec, validation, tests and transaction interface are designed. Explicit crop N ownership with future ANIMO5 also remains unresolved.

## Architecture implication

F-WOF-EXT01 now has: (1) an independent native Fortran daily numerical barley comparison against PCSE with research-only juvenile GLAIEX condition intervention, 12 outputs within 1e-12 and O0/O2 identical ([run 39059061721](https://github.com/abhedwig-cell/SWAP5/actions/runs/39059061721)); (2) real Python bounded direct-restoration proof at multiple split points in separate processes; (3) an isolated synthetic external transaction contract. This is stronger than replay-only recovery.

**Decision: CONDITIONAL GO for implementing a proper external daily backend research interface; NO-GO for production replacement until full crop state/coupled accepted events/rollback, reference variation, isolation and operational gate are qualified.** Do not modify admitted WOFOST81 production formulation on the strength of one pinned barley fixture.
