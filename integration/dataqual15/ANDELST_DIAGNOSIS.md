# DATAQUAL15: Andelst numerical diagnosis

Baseline: `d541180b32df692fa67c5fc795cc6b15e6812ed6`. No production code or numerical tolerance changed in this work unit. This is an authority reconciliation and a historical diagnostic, not new current-source qualification.

## Actual execution boundary

The full original 112-node, five-domain macro/Rutter/numeric-heat application has an inherited original-input experimental prefix of **2.7479999999995925 days**. The separately retained 481-day matrix-only route and short covered-macropore receipt are explicitly excluded from complete original Andelst migration. `COVERED_MACRO_TRACE_ADMISSION.json` states `full_original_Andelst=false` and `full481_reexecuted=false`.

DATAQUAL10 canonically repairs the fixed-geometry common-stock-cap Jacobian, including cross-cell low-rank feedback. It does not establish an original-stall breakthrough. Its own original continuation is censored after 60 seconds, last published forcing segment ending at 2.6600000000034925 days; the previous source's completed 2.748 prefix is inherited, not freshly requalified. Do not convert that budget censor into a numerical failure or complete daily result.

## One bounded exact historical replay

The hash-verified DATAQUAL07 capsule contains a matching executable, original prepared input and its own 2.748 checkpoint. One replay used the identical native command and binding from `integral/original-stock-five/run/manifest.json`, adding only existing observation switch `SWAP5_DIAG_MACRO_TEMPORAL=1`. No CRC or application binding was rewritten. The 30-second cap was selected to inspect the known failure without repeating a long campaign.

The process terminated after **16.533386909 seconds**, reproducing the original failure and exact numerical counters:

| Quantity | Reproduced value |
| --- | ---: |
| Newton iterations / linear solves | 29,878 / 29,878 |
| HeadCalc calls | 2,523 |
| Backtracking attempts | 88,805 |
| Accepted internal substeps before rejection | 416 |
| Solver / temporal / mass rejections | 102 / 402 / 0 |
| Smallest accepted duration | 8.881784197001252e-16 day |
| Internal failure time | 2.8486751098551224 days |
| Last published restart | 2.7479999999995925 days |

The rejected restart is byte-exact against the authentic 2.748 origin. The input checkpoint is unmodified. This verifies historical diagnostic reproducibility and rollback only; the source is DATAQUAL07, not current canonical.

## What the new measurements establish

All 39 sampled macropore-domain-bottom pairs match: `[92,64,57,49,39]`. Macropore volume and dynamic-volume differences are zero in all sampled full/half pairs. This excludes those recorded differences as the sampled error source. It does **not** establish identical matrix saturation-pocket or partial-top geometry, which the old diagnostics do not print.

The existing macro temporal norm directly compares all pressure heads and derived groundwater levels. Thirty-one of 39 observed norms equal the largest head difference; 23 records locate that largest difference at a node saturated in both siblings. For example, a 4.9218749973e-4-day pair has saturated heads 15.1330949543 and 15.1229961233 cm, norm 0.0100988301 cm, and maximum macro-stock difference 2.1489e-7 cm. This is a concrete reason to investigate an algebraic-pressure-sensitive temporal controller, rather than assuming all rejected work measures water-state error.

However, this is **not sufficient to diagnose the terminal barrier as the Grassgrowth temporal-norm bug**. Near the last accepted time, reducing duration makes the full/half norm tend to roundoff: at 8.8818e-16 day it is 2.8422e-14 cm, macro-stock difference 5.5511e-17 cm and derived groundwater levels agree. Subsequent failed trials report macro status 3, matrix status 2, zero completed outer iterations and 64 nonlinear iterations. The retained source therefore has a genuine Richards retry barrier as well as inefficient temporal assessment. Replacing only the norm is not an established repair.

## Residual/Jacobian scope and next correction

`mod_ppa_wu05a15_exchange_derivative.f90` deliberately skips the partially saturated top cell of a perched region. `mod_ppa_wu05a6_saturated_exchange_rate.f90` nevertheless multiplies its inflow by the moving matrix saturated fraction `(matrix_level - cell_bottom)/dz`. The DATAQUAL10 low-rank correction differentiates common stock caps **at fixed geometry**. It does not supply the missing derivative of matrix level, moving partial fraction or pocket/contact selection. This is a specific unqualified Jacobian dependency, not proof that it causes this failure.

The next decisive step is to retain the actual last accepted internal state near 2.8486751098551224, then record, for the first failed real Richards trial:

1. Maximum residual and node, pressure update, line-search outcome, linear-system residual and local diagonal/off-diagonal entries.
2. Matrix perched/main saturation endpoints, partial-top fraction, all active exchange switches and source groundwater/drainage feedback.
3. A directional finite-difference comparison of the **full active residual** with the assembled Jacobian using that same state and geometry. Differentiate continuous fraction/level feedback consistently; retain explicit one-sided/contact semantics at active-set changes.
4. Separately calculate unsaturated-head, water-storage, face-exchange, derived-GWL and algebraic saturated-head contributions to the existing temporal norm. An alternative norm must preserve actual mass, face flux, macro stock and topology controls and be qualified on the original trajectory.

This avoids another high-rain variant sweep, another iteration-budget increase or another capped-stock diagonal patch. It uses the original failing project itself.

## Control and scientific-equivalence limits

The historical route preserves original physical input but uses explicit experimental numerical policies. The original `.swp` specifies MAXIT=30, MAXBACKTR=4, DTMIN=1e-5 day and DTMAX=.002 day; the native-water launcher and retained replay use a 64-iteration budget. Consequently this result must not be called literal original solver-setting equivalence.

At the last accepted historical 2.748 source window, water residual is 6.3838e-15 cm, maximum matrix certificate 7.6268e-16 cm and combined certificate 9.8760e-16 cm. Earlier heat-accounting residual is 5.6090e-13 J/cm². These are bounded accounting checks, not whole energy or SWAP 4.3.1 trajectory equivalence. The rounded legacy comparison remains descriptive. Complete matched soil-moisture/head, ET, groundwater, drain, runoff and macro-state trajectories with quantity-specific justified tolerances remain absent.

Machine-readable evidence and source hashes: `ANDELST_DIAGNOSIS.json`; all 39 samples: `ANDELST_TEMPORAL_SAMPLES.json`; raw replay outputs: `ANDELST_HISTORICAL_DIAGNOSTIC.tar.xz`. The original sealed native/input/checkpoint authority remains `integration/dataqual07/STATUS.json` and its verified capsule; no large duplicate recovery bundle was created.
