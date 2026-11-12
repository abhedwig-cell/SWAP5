# F-WOF-EXT01: multi-split actual PCSE process replay qualification (2026-10-17)

**Research-only replay qualification PASS; full internal-state snapshot/restore NOT qualified.**

PCSE PR #9 research branch commit `23a2c1c007055e25568973416cf258500eb337db`; [GitHub Actions run 39059316543](https://github.com/abhedwig-cell/pcse/actions/runs/39059316543), job `117473833089`, completed SUCCESS.

Real PCSE Engine with pinned Spring_barley_301, crop-only external ET and no internally owned soil-water model. For each recovery split, a child process runs from initial condition to the selected accepted day, exits, then a new process rebuilds the Engine, replays the interval, verifies the prior observable trajectory against a saved record, and continues to day 60. Actual executed assertions:

- split after 10 days: `EXT01_REPLAY_SPLIT_EQUAL 10 61`;
- split after 30 days: `EXT01_PROCESS_REPLAY_RECOVERY_EQUAL 61`;
- split after 45 days: `EXT01_REPLAY_SPLIT_EQUAL 45 61`;
- intentional corruption of the saved day-30 LAI by +0.01: resumed process rejected the prior record, did not emit a continuation file, `EXT01_REPLAY_TAMPER_REJECTED`.
- All replayed output lists equal the separate full 61-row (60-transition) uninterrupted PCSE reference, including the twelve crop-owned observables and dates. PCSE workflow's other external day/stress/crop-reference checks also passed.

**Precise limits:** The equality test covers observable crop output, not a serialized internal engine-state image; not all unobserved rates, leaf cohorts, clock, events and stress histories are checked independently. Rebuilding by full replay has linear recovery work with elapsed simulation history, requires a complete immutable daily forcing/parameter/calendar/event ledger and version-pinned science, and is not a qualified replacement for atomic crop-state restart at SWAP5 scale. The corrupted-output test detects mismatch during replay; it does not cryptographically authenticate an event ledger or prove robustness against malicious edits to both ledger and reference.

The existing experimental native Fortran GLAIEX condition intervention was separately qualified within one fixed 60-day barley case in [run 39059061721](https://github.com/abhedwig-cell/SWAP5/actions/runs/39059061721). This does not establish inter-language equality for other crops/stress settings.

**Decision:** conditional GO for research process-loss recovery by replay, NO-GO for a production full-state crop restart guarantee or production WOFOST replacement. Next dependency-ordered package: specify versioned complete crop-owned state and day-event identifiers; independently test snapshot/restore and rejected/pending event semantics against actual PCSE Engine; then matched accepted SWAP5 hydrological event and timing, multi-case science and performance comparisons. Do not equate synthetic process-boundary test with integrated PCSE/SWAP5 runtime.
