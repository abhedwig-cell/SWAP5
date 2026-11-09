# Andelst V9 zero-inflow Jacobian test

The historical matrix-only cap test refused the first afternoon of the
dry window. This follow-up leaves the flux law and acceptance thresholds
unchanged and disables the inflow storage projection only when the
optional cap is allocated and the accepted rate bundle reports exactly
zero inflow fraction. An active outflow projection remains possible.
The experiment does not supply derivatives of a moving interface or
change the derivative for partially capped inflow.

## Model execution

Base a27427f40934a90042b29045f9b3224fdf4d343d. GNU Fortran 13.3,
O2 with runtime checks. Build with render_clamped_jacobian.py and the
same arguments as render_legacy_matrix_cap.py. Use the pinned Linux
day-453 restart, the five original V9 archive inputs and the year-replay
launch vector with the final day and absolute stop set to 457. Copy
input.bbc and input.dra to swap.bbc and swap.dra in the run directory.

| Result | Measured |
|---|---:|
| Committed source intervals | 296 |
| Last committed time, day | 453.59200000000283 |
| Rejected interval end, day | 453.59400000000284 |
| Attempts in refused interval | 86 |
| Solver rejections in refused interval | 71 |
| Temporal and mass rejections in refused interval | 0 |
| Maximum absolute committed source interval residual, cm | 6.8012e-14 |
| Daily budget records | 0 |

The parent all-domain cap refused the same interval with 70 solver
rejections. The modified derivative therefore does not recover the first
day. There is no candidate day boundary, restart test, or dry-window
scientific qualification for this variant. The diagnostic checkpoint is
at the last committed time. The test rules out this correction by itself.

Executable SHA-256:
fedabbb7145df7ea0a96be7e961bdaa8e8837d9eaf1035e65464e884d120e4a3.
Diagnostic checkpoint SHA-256:
985e9abfa071867188ecb5af1147ebc3072cc28474055e5df7b73a0ff88977cb.

## Next functional work package

Advance the original water core through the existing SWAP5-owned
day transaction for the historical Andelst trajectory. Reuse the B0
day return, continuation sidecar and kernel donor adapter. Start with
continuous runs and fresh-process day replays spanning both the crop/year
transition and the dry window. Use the original Cauchy series and legacy
internal solver and rejection sequence. Check all daily water stocks and
boundary fluxes, compare against uninterrupted B0, and interleave two
independent histories against their isolated controls. Extend to the full
481 days once both windows replay. Use existing water-balance and
scientific criteria and retain all existing failures. A restart mismatch
first requires locating and fixing the missing continuation state at the
day interface. This work package does not depend on a MODFLOW run.
