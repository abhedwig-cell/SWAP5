# PERF01 solver-aware proposal diagnostics

Status: bounded diagnostic result, 21 October 2026. Production policy remains
unchanged and default OFF. Baseline canonical
`fcfdd3ae6bb2c9516c6e303b7aa112e418e04b3d` includes the admitted MC-SOL01
thermal extension; its added providers are outside this unchanged 178-provider
column closure. This study changes no production, reference or incumbent tool.

The [previous temporal study](SWAP5-PERF01_TEMPORAL_STUDY.md) found wet gains but
a 2.27-fold dry regression. All experiments here use the same real coupled
water/solute application, eight 0.001-day windows, five column inputs, unchanged
acceptance checks and the diagnostic exact-endpoint targeting correction.
Nothing is relabelled after solving. Physical formulas, solver tolerances,
mass checks, chemical endpoint checks and restart schema are unchanged.

## Causal screen

The original proposal uses temporal error to grow an accepted step even after
nonlinear solver rejection. Simply limiting growth is insufficient:

| Dry32 policy at tolerance 1e-6 | Attempts | Accepted transactions | Solver rejections | HeadCalc calls | Disposition |
| --- | ---: | ---: | ---: | ---: | --- |
| Default OFF | 673 | 153 | 278 | 1668 | Baseline |
| Cap growth at one after rejection | 1460 | 940 | 502 | 3450 | Reject performance hypothesis |
| Retain minimum successful step ceiling | 3820 | 3746 | 56 | 11372 | Reject performance hypothesis |
| Raise ceiling by 25% after eight successes | Incomplete | Incomplete | Incomplete | Incomplete | Native substep-limit failure |
| Fall back for remainder of requested window | 655 | 153 | 263 | 1632 | Select for bounded follow-up |

The recovery variant fails in the first window with water status 4,
`CANONICAL_STATUS_SUBSTEP_LIMIT`. Both external committed clocks remain zero
and no chemical substep completes. It remains a failure in the evidence,
never a successful timing sample. The first wrapper version did not save its
own terminal source copy on failure; its identical source is retained in the
successful cap/ceiling capsules, and the failed generated Fortran, commands and
logs are retained directly. The current wrapper saves its identity on failure.

The selected rule remembers whether any accepted transaction in the current
requested interval incurred a solver rejection. Thereafter it disables proposal
targeting until that interval ends, so subsequent targets use the incumbent
requested endpoint. Memory resets at every reporting window; no new persistent
state or solver-internal dependency is introduced. This does not undo an already
accepted transaction, so dry trajectories need not equal default OFF exactly.

## Fresh candidate results

GNU Fortran 13.3.0, production O2, median of three interleaved paired repeats.
CPU covers only the real joint interval call, excluding diagnostic output and
snapshots outside that call. These are new measurements, not the previous
study's samples. Timing variability remains in the raw reports.

| Case | Default CPU s | Fallback CPU s | Default / fallback | Attempts default / fallback |
| --- | ---: | ---: | ---: | --- |
| Pond4 | 0.188173 | 0.023199 | 8.11 | 6784 / 835 |
| Pond32 | 0.371221 | 0.058633 | 6.33 | 3705 / 541 |
| Pond256 | 0.366762 | 0.106836 | 3.43 | 624 / 160 |
| Dry32 | 0.056548 | 0.054933 | 1.03 | 673 / 655 |
| Pulse4 | 0.169306 | 0.021865 | 7.74 | 6784 / 835 |

Dry performance is approximately parity, not a robust speedup claim. Its
HeadCalc count decreases by 2.16%, nonlinear iterations by 2.75%; the prior
dry regression is absent in this bounded case. Wet and pulse physical outputs,
trajectories and restart bytes match the incumbent proposal in all 16 matching
case/tolerance observations. Their numeric work is unchanged.

## Accuracy and preserved contracts

O2 uses tolerances 1e-6, 2.5e-7, 6.25e-8 and 1e-9. O0 uses the first two.
Maximum head differences decrease under refinement against both finite 1e-9
references for every case. For dry32, differences against the default reference
are 4.24e-5, 2.04e-5 and 9.48e-6 cm at the first three tolerances; the two fine
routes coincide. For pond4 they are 5.45e-4, 2.66e-4 and 1.26e-4 cm. The default
and proposal fine references still differ by 3.76e-6 cm in pond4.

These references are finite numerical solutions, not analytic truth or a new
global error guarantee. There is no claim that the optional policy at the same
local tolerance is uniformly as accurate as the incumbent path. Dry1e-6 differs
from default by at most 7.19e-7 cm head and 3.80e-11 volumetric water content.

All 45 shared O0/O2 observations have exactly identical physical file bytes
and numeric work counters. All 20 candidate policy/case/optimization split
restarts reproduce final state, endpoint and restart bytes plus resumed budget
and trajectory rows. Every default-OFF observer matches the uninstrumented
application. Maximum candidate reporting-window residuals are 1.13e-12 cm water
and 6.07e-13 mg/cm² solute. No candidate mass rejection occurs and no acceptance
assertion is relaxed.

There are 159 new native executions: 29 in the causal screen including its one
failure, and 130 completed candidate observations. The evidence verifier checks
every current production provider, generated source identity, physical file
digest, native disposition, work inventory, exact restart, optimization equality
and wet preservation against the preceding immutable capsule. Its five negative
controls reject altered runtime, state, restart, trajectory and provider bytes.

## Recovery and scope

The owning record is
`integration/performance/SWAP5-PERF01_SOLVER_STUDY_STATUS.json`. Evidence is under
`integration/performance/evidence/perf01-solver-{screen,candidate}-20261021/`.
Each archive has a checked SHA256, full member inventory and per-member hashes.
Generated source and raw scientific files are included; binaries are excluded.

Reproduce with separately verified original O0/O2 builds:

```bash
python integration/performance/study_solver_proposal.py --solver-policy fallback \
  --build /path/to/build-O2 --output /tmp/new-temporal-O2 --repeat 3
python integration/performance/study_solver_proposal.py --solver-policy fallback \
  --build /path/to/build-O0 --output /tmp/new-temporal-O0 --repeat 1 \
  --tolerances 1e-6 2.5e-7
python -B integration/performance/verify_solver_study.py
python -B integration/performance/verify_solver_study.py --self-test
```

The unchanged current owning authority remains binding. The earlier nine
diagnostic registration controls are selected at their exact 3cb20b8a predecessor
because the later thermal owner intentionally supersedes that source boundary.
Full moving F-CI and highest low-air stress are not selected for these diagnostic
and documentation additions. No hosted compiler run substitutes for the local
observations. Compile/link/controller overhead was not separately timed here.

This finding supports a conservative candidate for separate production-policy
qualification. It does not implement that candidate in production, activate the
optional setting generally, or establish seasonal, crop/heat/BBC, regional HRU
or SWAP4.3.1-relative performance. Production implementation requires an owning
execution-policy contract, runtime state/failure tests and explicit admission
of the changed numerical trajectory. The existing exact PERF01 optimization
and RossFast scope remain unchanged.
