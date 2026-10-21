# PERF01 dry infiltration: total-balance stagnation

Historical baseline diagnosis, not a solver correction or extension of the
[optional policy admission](SWAP5-PERF01_PROPOSAL_RESULT.md). Executed against
`c62ca4ce2e33c65be3630f947b8ff322cd2f9863` with GNU Fortran 13.3.0. The separate
diagnostic owner is `integration/diagnostics/SWAP5-PERF01_DRY_DIAGNOSIS_STATUS.json`.
Existing production qualification authorities and their assertions are unchanged.

## Established observations

Four native executions, O0 checked and O2 production, optional proposal OFF and
ON, reproduce the retained 32-cell initially dry infiltration failure. All four
have byte-identical partial budgets, accepted physical trajectories and failed
external-clock reports, and identical deterministic work counters. The rejected
sixth requested window is [0.078125, 0.09375] day; both external clocks remain
0.078125 day and chemical completed substeps remain zero for that window.

The generated diagnostic HeadCalc records its last 64 nonlinear exhaustion
states **before** the original reset. A generated application main dumps the
ring only after the joint interval fails. No production source, tolerance,
retry budget, acceptance test or executable is modified. The serial ring is
diagnostic-only process state, not an API, restart field or production observer.

All four terminal rings are byte-identical. In each of the last 64 exhausted
solves, all compartment residuals and head increments satisfy their effective
tolerances, and the pond failure flag is false. The terminal head increment is
exactly zero. The **sum of
the compartment residuals** exceeds the total-balance tolerance. The final
HeadCalc call is 575594, matching the sum of all reported calls in six windows.

| Final solve quantity | Measured value |
| --- | ---: |
| Step duration | 6.730352386519201e-12 day |
| Largest compartment residual | 1.935357547733809e-6 cm/day |
| Total residual | -4.520616382431123e-5 cm/day |
| Effective compartment and total tolerance | 4.160257649522721e-5 cm/day |
| Integrated total residual | -3.042534125803310e-16 cm |
| Existing integrated floor | 2.8e-16 cm |
| Final scaled head increment | 0 |
| Final-window solver / temporal / mass rejections | 54874 / 77059 / 0 |

The backend already computes each balance tolerance as the maximum of its
configured rate tolerance and `2.8e-16 / step_duration`. Thus the observed failure
is not simply an unscaled 1e-12 rate threshold. The unchanged total-balance test
rejects the stagnant final iterate even though every compartment passes. The
legacy `fldtmin` shortcut is false in every retained exhaustion state; this
diagnosis does not claim that the configured minimum duration is an enforced
transaction cutoff.

## Interpretation and remaining gap

The zero head increments, very small integrated residual and one-theta-ULP
storage-rate scale of 2.061970460211187e-5 cm/day at the worst residual node are
consistent with finite-precision stagnation. This is an **inference**, not an
independent high-precision balance proof. That ULP estimate is a scale indicator,
not a certified rounding-error bound for the whole column. The evidence does not
establish that adding iterations, compensated summation, a different storage
formulation, a larger tolerance or more retries solves the scientific problem.

A correction would need a separate numerical contract, a small reproducible
stagnation fixture, independent conservation/error evidence and unchanged
external failure atomicity. Merely increasing the total tolerance is not selected.
The long infiltrating dry32 regime remains excluded from production policy
qualification; its full-day runtime and accuracy remain unknown. Existing wet
and quiet dry performance claims are unchanged.

## Evidence and reproduction

Run `python integration/diagnostics/verify_perf01_dry.py --self-test` to verify
the archived raw evidence, original retained oracle, all 177 reused object hashes
per build, historical provider identities, native nonzero exits and all four
terminal rings. Five negative controls reject missing or altered evidence,
relabelled native success and generated-source changes. The source authority
for every original compiled provider is the pinned baseline, not a moving branch.

The generator is `integration/diagnostics/diagnose_perf01_dry.py`. Supply
`--build` with the original column build directory, `--input` with the retained
dry32 namelist, `--oracle` with its original failing run and `--output` with a new
directory. It checks provider/executable identities, recompiles only HeadCalc
and the observing main, retains FPE traps, and executes OFF/ON serially with a
120-second limit per process. Both measured profiles complete within that bound.
All paths, compiler options and linked object hashes are archived in BUILD.json.
The application-level `transaction_failure.csv` uses -1 for unavailable internal
retry index and transaction duration; its counts cover the failed reporting
window. The actual final solve duration is in `solver_failure.csv`.

The evidence also retains unsuccessful instrumentation preflights. A missing
executable locator and nonunique source anchor were corrected before execution;
one generated source did not compile. One early native invocation lacked the
explicit fresh-run sentinel and rejected restart. An abandoned transaction-module
shadow failed before any accepted window with an allocation runtime error. These
are not solver observations or qualified executions. The final design retains
the original transaction object, reproduces all original counters and budgets,
and archives all preflight logs separately from its four completed diagnoses.

Concurrent nonlinear pond admission at `8fabce512cc6347815fff591650be198c0ce213f`
changes the admitted sorption exponent guard, not HeadCalc or its backend. This
diagnostic composes as historical evidence without rebinding its original native
builds to that newer source or claiming a fresh current full-day qualification.

Affected invariants: 3, 5, 7, 22, 23, 25, 26. Observation only; production solver
ownership, hard mass acceptance, rollback, restart and default-OFF policy remain
under the existing authorities. No hosted compilation or full F-CI is claimed.
