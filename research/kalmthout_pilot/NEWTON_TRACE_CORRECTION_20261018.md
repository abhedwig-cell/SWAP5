# Correction to prior Kalmthout Newton trace classification (2026-10-18)

**The previous analysis was wrong.** In `src/legacy/b1_10_port/headcalc.f90`, the `KALMTHOUT_NEWTON` format prints `state%ftoph` as its final logical field, *not* an `accepted` flag. `ftoph` denotes head-controlled top boundary. The prior extracted CSV column `accepted` is misnamed, and interpreting 881 `F` records as rejected / 131 `T` records as accepted Newton candidates is invalid. Withdraw those acceptance claims from `NEWTON_TRACE_CLASSIFICATION_20261018.md` and previous narrative.

The supported facts from 1,012 records are 881 surface-flux rows and 131 ponded-head rows. Flux candidate top-head extremes are real observations in the logged candidates, not proof of their eventual acceptance or rejection. The actual backtracking rule in `headcalc.f90` tests `sump < sumold` or `Fmax < CritDevBalCp`; this decision is *not* explicitly recorded as a boolean in the old trace. A successful Newton backtrack is also not a committed hourly simulation.

Corrected local artifact: `newton_steps_corrected_20261018.csv`, replacing ambiguous column header by `top_head_mode_active`. Source run 39125001908, artifact 12135892353. Next step: explicitly log backtracking acceptance/rejection and full accepted column state in a focused run. Avoid changing solver policy or weakening mass balance gates.
