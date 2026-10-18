# Kalmthout Newton trace: exact residual-decrease classification (2026-10-18)

Source: existing Actions run 39125001908, artifact 12135892353, file `dry_diagnostic.log`, raw SHA-256 `444e49b76aaaa3e0b7fe780d52194c0690b10cc1c46e1e4f15742056ee931d28`.

Actual `KALMTHOUT_NEWTON` record fields in `src/legacy/b1_10_port/headcalc.f90`: iteration, backtrack, ftoph integer, dt, previous pond, old/trial top head, trial pond, top flux, sump, sumold, Fmax, ftoph logical, route. The logical T/F marks `ftoph`, NOT candidate acceptance.

Counted all 1012 records, comparing the printed `sump < sumold` (only the first part of the backtracking criterion):

| route | sump < sumold | sump >= sumold | total |
|---|---:|---:|---:|
| surface-flux | 0 | 881 | 881 |
| ponded-head | 105 | 26 | 131 |
| TOTAL | 105 | 907 | 1012 |

**Interpretation**: 105 records satisfy the residual-norm-decrease half of the backtracking decision. The remaining 907 cannot be classified as automatically rejected, because the actual code uses `sump < sumold .OR. Fmax < CritDevBalCp`. The actual tolerance must be obtained per step before a total candidate acceptance count is justified. The previous claim that all flux trials were rejected / head trials accepted was invalid and withdrawn.

Further caveats: decimal log rounding can affect exact equality at extreme precision; `sump` is a squared residual norm, not the per-node balance; these are candidate records and do not by themselves establish hour completion. No new SWAP5 execution, no full accepted-state export, no Jacobian correction. No change to canonical, hard gates or RossFast.

A local corrected CSV of 1012 rows with derived `residual_decreased` was generated and checked; it is not being committed as immutable source evidence until a suitably stable evidence-data surface is selected.
