# F-WOF-EXT01 restart qualification: actual separate-process result (2026-10-17)

## Experiment and results
PCSE research PR #9, source candidate `1305a2c5b9d8e3e1cb66cef5330329638860517b`, GitHub run 39044474691 SUCCESS.

- Two separate child Python processes executed from the same pinned research checkout.
- First child initialized the real crop-only WOFOST81 barley Engine, executed 30 days and saved all observable crop outputs and dates.
- After that child exited, second child initialized a *new* WOFOST81 Engine from the identical parameters/weather/calendar, replayed the first 30 days, checked that all 12 observed crop-owned variables matched the saved prior output and then advanced 30 more days.
- The resulting full 61-record trajectory exactly matched an independent uninterrupted 60-day run: `EXT01_PROCESS_REPLAY_RECOVERY_EQUAL 61`.
- This is a **replay-based process recovery** strategy, NOT a checkpoint/restore of internal PCSE state. Its computational replay cost grows with crop history. Complete immutable forcing/event history is essential for correctness, especially when forcing is supplied by SWAP5.
- The immediately preceding exact full-object `pickle.dump(engine)` experiment failed at `N_PotentialProduction.integrate` because dynamically wrapped PCSE functions are not reliably picklable. Run 39044354011 records this negative witness.
- Python pickle is not an acceptable stable, safe, versioned scientific restart format and must not be adopted in SWAP production. Do not claim full PCSE snapshot success.

## Architecture implication
Production external WOFOST still requires a **versioned scientific state codec** for crop developmental state, phenology, all leaf cohorts, N state/rates, crop calendar events, timer, stress histories and pending day event, or explicit admission of replay-only recovery with its substantial performance/storage trade-off. Neither has been approved.

## Status
- Separate-process *recovery by replay*: PASS on bounded 60-day synthetic-water barley case.
- Direct full-engine pickle checkpoint: FAIL (concrete incompatibility).
- Complete source-stable internal state serialization/restoration: OPEN.
- Independent same-input Fortran reference test: OPEN.
- SWAP5 production integration: NOT ADMITTED.

This document is research evidence, not a source-admission or software release decision.
