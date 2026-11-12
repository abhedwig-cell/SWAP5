# F-WOF-EXT01: real PCSE internal leaf continuity, 2026-10-17

## Executed evidence
- PCSE research PR #9 commit `acc2a31aa1228384fc2750ab5d56b3547e9fb5e7`, targeted GitHub Actions [39059776237](https://github.com/abhedwig-cell/pcse/actions/runs/39059776237), job 117475163449 SUCCESS.
- Pinned Spring_barley_301 crop-only actual PCSE engine; separate Python child processes start a new Engine after days 10, 30, 45 and replay the first days from identical original inputs.
- For each split, compare previous output history **and a bounded actual internal crop-state projection**, not merely published outputs, before continuation. Projection includes every extant leaf cohort LV/SLA/LVAGE, LASUM, LAIEXP, LAIMAX, WLV, DWLV, TWLV, crop development DVS, TAGP, day. Reconstructed trajectory equals uninterrupted 61-row output for 60 transitions.
- Negative tests: altered visible LAI output receipt rejected; separately altered *hidden first leaf cohort LV* in the stored internal-state receipt rejected before continuation, with no continued output file. Exact log markers `EXT01_REPLAY_SPLIT_EQUAL 10 61`, `EXT01_REPLAY_SPLIT_EQUAL 45 61`, `EXT01_PROCESS_REPLAY_RECOVERY_EQUAL 61`, `EXT01_REPLAY_TAMPER_REJECTED`, `EXT01_INTERNAL_LEAF_COHORT_TAMPER_REJECTED`.
- Previous qualification [39059679774](https://github.com/abhedwig-cell/pcse/actions/runs/39059679774) also passed the internal leaf-state projection comparisons without the additional negative cohort test.

## Qualification boundary

**PASS:** bounded restart-by-replay reproduces tested PCSE observable trajectory and the selected hidden leaf cohorts and development state; independently detects corruption of either recorded output or a selected internal leaf value.

**NOT PROVED:** direct binary/scientific state checkpoint/restore, all nested PCSE Engine/Timer/Agromanagement/N-stress internal state, exactly-once SWAP accepted event ledger, rollback of a live real PCSE candidate, nonstationary accepted hydrology/event sequence, multi-crop or performance cost. No full-state codec is implemented here. All comparisons are replay reconstruction using unchanged inputs, not restoring saved leaves into a running engine. Therefore never call this a full PCSE checkpoint qualification.

## Architecture decision

Research daily external WOFOST is supported by matched native O0/O2 scientific barley case (SWAP5 [39059061721](https://github.com/abhedwig-cell/SWAP5/actions/runs/39059061721)) and real PCSE multi-split process replay with internal state witnesses. CONDITIONAL GO for a research backend seam. NO-GO production replacement until complete state/restart and real accepted SWAP5 hydrological event gates; existing admitted Fortran implementation remains untouched.
