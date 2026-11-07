# Andelst B0 matrix/macropore iteration

Base: `3d9cc2f93becd76cc5e3ae94c60097304cefa5fb`. Linux GNU Fortran
O2 donor, original Andelst input, unchanged day-4 checkpoint, 0.002 d
step cap, split at 35799.25 and stop at 35799.5. Cauchy heads are
-50.021093875271006 and -50.0208036016698 cm. This is an experimental
donor test. There is no change to the source distribution or canonical.

## Where the response separates

The historical case sets SWBOTB=3 and SWBOTB3IMPL=1. BoundBottom sets
the imposed deep head, but the accepted bottom flux is computed again
in HeadCalc using the bottom node head and conductivity. The diagnosed
internal groundwater level is relevant to the macropore calculation.
It is not the direct driving head in this case's final Cauchy equation.

At the first step the largest pressure difference is at the bottom
node (112). By step 8 it is at node 57. The baseline uses the same
number of Newton iterations in each run for the first 25 steps. The
first different groundwater-table node after SoilWater(3) is at step 26.
The accepted time grids are identical through step 149.

HeadCalc's small-step macropore shortcut freezes the exchange after
three qualifying iterations via flunsatok(3). The residual then uses
the retained QExcMpMtx and the Jacobian omits its derivative. Newton
convergence for that residual does not establish convergence with
exchange recomputed at the accepted head. This branch is active at
the early steps of both baseline runs.

| Accepted step | Baseline max nodal head difference (cm) | Recomputed exchange (cm) | Baseline internal water-table difference (cm, A minus B) | Recomputed exchange (cm, A minus B) |
|---:|---:|---:|---:|---:|
| 1 | 0.00018854 | 0.00018854 | -6.84e-10 | -1.89e-12 |
| 8 | 0.00756120 | 0.00019046 | 0.00511010 | -3.06e-6 |
| 13 | 0.12485352 | 0.00019155 | 0.08543957 | -5.93e-6 |
| 30 | 3.10384291 | 0.00019480 | -2.00227319 | -1.53e-5 |

At step 30 the maximum matrix/macropore exchange-rate difference falls
from 0.04283 to 2.68e-6 cm/d. Both modes still share their time grids
between the two imposed heads at that step. This intervention changes
both the exchange evaluation and its linearization. The experiment
isolates the effect of that combined shortcut, not its two parts.

## Whole-window check

| Mode | Accepted steps A/B | Integrated inward bottom flux A/B (cm) | Water residual A/B (cm) |
|---|---|---|---|
| Baseline | 820 / 778 | 0.1081205403 / 0.1081968256 | 5.56e-10 / -4.07e-11 |
| Recompute every iteration | 4130 / 4174 | 0.0806523900 / 0.0809223888 | -1.34e-7 / -1.42e-7 |

The paired baseline replay with observations reproduces the original
accepted trajectories and endpoint files. Continuous exchange
recomputation dampens early amplification, but increases the paired
half-day flux difference from 7.63e-5 to 2.70e-4 cm. It also changes
the level of total exchange by about 25% and requires around five times
as many accepted steps. The two standalone water ledgers still satisfy
the existing 1e-6 cm mass criterion.

## Reproduction

Reuse the paired replay in the README. Add read-only output in the
generated swap.f90 immediately before SoilWater(3) for nodgwl, numbit,
idecmprat, t1900, dt, gwl, pegwl, qbot and QExcMpMtx(1:numnod).
After the call, record nodgwl, gwl, pegwl and qbot. At successful
Newton return in HeadCalc, record numbit, iBackTr, flunsatok(3),
flnonconv3, fldecMPmbf, t1900, Fmax and sum1.

In a private copy of the reference objects, rebuild headcalc.f90 with
the donor compiler settings. In vector_F, call MACROPORE(2) whenever
swmacro=1, removing the frozen-exchange branch. In jacobian_F, use
swmacro=1 alone to guard MACROPORE(3) and its derivative. Leave all
solver thresholds, original inputs, checkpoint and SWAP5 coupling
criteria unchanged. Substitute only the rebuilt headcalc.o in the
existing half/full worker link. Run the same paired replays and the
live driver with `--mf6`, `--max-step-days 0.002` and `--bracketed`.

The live probe rejected its first SWAP trial at -50 cm before calling
MODFLOW. Full versus split differences were 0.002615 cm in total
column stock, 0.001412 cm in the largest stock component and 0.0005953
cm in bottom exchange, against 0.0001 cm per criterion. Accepted
revision remained zero and the origin hashes were unchanged.

Keep the original donor as the comparison control. For a replacement,
test the exchange recomputed at the accepted head before committing
a Richards step. A failed consistency check must trigger a bounded
continuation of the same iteration or a rollback and retry. Measure
full versus split stock and exchange from the same origin before
starting another MODFLOW corrector campaign. Continuous recomputation
by itself is rejected as a replacement for this window.

A separate short replay to 35799.06 tested the two edits independently
from the same origin. Baseline and the consistent change to both
residual and Jacobian each took 30 accepted steps per head. Refreshing
only the residual took 777/777 steps; updating only the Jacobian took
774/772. These deliberately inconsistent Newton variants are diagnostic
controls. Their timestep reductions prevent attribution of the
same-grid pressure effect to either edit in isolation.
