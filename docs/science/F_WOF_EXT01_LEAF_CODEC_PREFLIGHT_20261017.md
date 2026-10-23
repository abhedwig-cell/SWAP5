# F-WOF-EXT01 real PCSE leaf cohort state codec preflight, 2026-10-17

Research-only qualification. **NOT a full PCSE Engine state checkpoint or direct restart.**

## Executed
PCSE PR #9 commit `5cde84dd2671cbc4a36674f27ad63a80fd97b623`, [targeted run 39060510855](https://github.com/abhedwig-cell/pcse/actions/runs/39060510855), job 117477341981 SUCCESS. Tests operate on real PCSE Spring_barley_301 crop-only engines. A strict versioned JSON leaf *projection* exports all leaf cohort LV, SLA, LVAGE entries and bounded associated crop DVS, day, WLV, DWLV, TWLV, LAIEXP, LASUM, LAIMAX, TAGP. On days 10, 30, 45, encode -> decode reproduces the selected in-memory values exactly; cohort counts are respectively 11, 31, 37. Tests reject schema mismatch, missing fields, unknown fields, nonfinite numbers, and cohort vector length discrepancy.

Markers:
`EXT01_REAL_LEAF_PROJECTION_CODEC_PASS 10 11`
`EXT01_REAL_LEAF_PROJECTION_CODEC_PASS 30 31`
`EXT01_REAL_LEAF_PROJECTION_CODEC_PASS 45 37`
`EXT01_INCOMPLETE_STATE_FAIL_CLOSED_PASS`

This is **a serialization and validation preflight only**, with real state extraction. The decoded projection is NOT installed into a new engine; no run continues from it. Direct restart additionally requires all nested crop components, rates/continuation, simulation clock, agromanagement event pointer, kiosks, signal subscriptions and authoritative accepted event receipt. Neither source-stable full-state codec nor direct state-resume is implemented. Existing separate-process replay of internal leaf cohorts and 61 published observables at three split points (run 39059776237) is independent supporting evidence, not a substitute.

## Decision
Conditional GO research, NO-GO production replacement. The most recent matched Python–Fortran 60-day stress-mode barley scientific A/B test (run 39059061721) passed only in the controlled temporary Fortran juvenile `GLAIEX` condition; do not silently mutate admitted production physics. Next implementation milestone should be a versioned full crop-event state codec with exact restore and continued trajectory without historical replay, followed by real SWAP accepted water event transactional semantics.
