# GC-RZM06A3 micro-stepped H2 construction result

Date: 2026-09-22  
Preregistration: `c41b702dd2a87b6c94a482f0d384454b745a0f44`  
Implementation: `e6fc952906f4be6ae40667ecef4e6e7045bc8e03`  
Qualified workflow: `35727742747`, job `106745456506`  
Production changes: none

## Decision

RZM06A3 is qualified as a transition-admissibility falsification. It does not produce an H2 endpoint pair and does not probe H2.

The formal disposition is:

`QUALIFIED_TRANSITION_ADMISSIBILITY_FALSIFICATION__H2_NOT_PROBED`.

## Stage 1: short-window admissibility

The frozen baseline grid contains 56 `δH × duration` points. Twenty-nine are admissible in both directions.

The preregistered score rule selects:

- `δH = 1e-5 m`;
- `duration = 0.005 d`;
- score `δH × duration = 5e-8 m d`.

This point is exactly repeatable from fresh initialization in both directions. The plus trial uses 14 accepted substeps and 46 temporal retries. The minus trial uses 14 accepted substeps, 47 retries, one solver rejection and 46 temporal rejections. Both are mass-complete and read-only.

A second point, `δH = 5e-6 m`, `duration = 0.01 d`, has the same score, but the preregistered tie rule chooses the larger `δH`. It is therefore not substituted after seeing Stage 2.

## Stage 2: transition failure

Fifteen opposite-order constructions were attempted for:

- `N = 200, 100, 50, 20, 10`;
- `R = 1, 5, 20`.

For every configuration both trajectories accept all N first-sign intervals. Every trajectory then fails on the very first opposite-sign interval.

Examples:

- for `N=200`, the origin reaches revision 200 and time 1.0 d before the first sign reversal fails;
- for `N=10`, the origin reaches revision 10 and time 0.05 d before the reversal fails.

The failed reversal is transaction-safe. It does not change the latest accepted revision, committed time, ledger or endpoint observables.

The common failure signature is retry exhaustion dominated by temporal rejection, with small solver-rejection counts. There is no accepted-state mass defect.

## Interpretation

The main new result is architectural rather than hydrological:

**two-sided admissibility from one baseline origin does not imply transition admissibility from an evolved committed origin.**

That distinction matters for any research or production-facing tangent/corrector logic that reuses local boundary perturbations. Admissibility is state-dependent.

This also explains why simply making the long RZM06A2 pulse smaller was not sufficient. The relevant failure is not only the absolute perturbation from H*. It is the perturbation relative to the current committed trajectory state and its numerical continuation/history.

RZM06A3 does not falsify H2. No complete opposite-order endpoint pair exists, so no E_c probe was opened and the original H2 thresholds remain untouched.

There is also a practical scale result. Across the frozen N values, the largest separation already present immediately before the failed reversal is only about `2.2664e-7` in M1. The H2 requirement remains `1e-4`. The observed separation is therefore roughly 441 times too small. Repairing only the sign reversal is not a well-supported next primary experiment.

## Next work unit

RZM06A4 will instead target stronger vertical redistribution through prospectively characterized top-boundary forcing while keeping H_c fixed. It will first determine a symmetric accepted forcing scale without looking at E_c, then construct opposite-order zero-net-top-forcing histories and apply the unchanged H2 endpoint criteria.

No retry budgets, temporal budgets, mass gates or H2 thresholds will be changed.
