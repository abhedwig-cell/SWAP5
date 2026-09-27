# F-PE-HYDTABLE01 closeout

Date: 2026-09-27

Status: `CLOSED_REJECTED_SOLVER_RUNTIME`

PR:
`#659 — F-PE-HYDTABLE01: bounded conductivity table research`

## Outcome

HYDTABLE01 tested whether the still-analytical MvG conductivity and smooth dK/dh route could be accelerated with a bounded shared table.

The answer is split:

- as a numerical representation, yes;
- as a Richards-solver performance optimization, no for the frozen candidate.

## Evidence

P0 calibration and independent holdout showed that the frozen N=1024 logK/log(-h) table can represent the tested B01/B12/O05/O14 conductivity range with:

- worst holdout relative K error about 8.88e-5;
- worst holdout relative dK/dh error about 1.32%;
- monotonic and nonnegative K;
- correct analytical fallback at the frozen wet/dry boundaries;
- several-fold lower isolated K-evaluation cost.

P1 then inserted the frozen representation into the real constitutive provider used by the Reference Richards solve.

After removing an implementation artifact that redundantly computed analytical K before overwriting it, P1 still measured:

- 12/12 solver convergence;
- identical nonlinear-iteration counts;
- identical backtracking counts;
- median candidate/reference runtime ratio 1.029395;
- 0/12 materially speed-positive cases;
- 11/12 cases more than 2% slower.

## Decision

The frozen candidate fails the preregistered solver-performance gate.

Do not:

- widen P1 acceptance to rescue it;
- proceed to combined AHL+A2C+c0.65 qualification;
- admit a K table to production;
- infer solver benefit from the microkernel benchmark.

No production `src/**` change was made.

## Performance-program handoff

The result strengthens the case for decomposing the unavoidable base q/state Richards solve directly rather than continuing to optimize isolated constitutive arithmetic.

Current canonical performance authority has already opened:

`F-PE-BASE01 — base q/state Richards solve decomposition`

PR #660.

That workunit is the correct immediate successor because it measures where time inside the live required Reference solve is actually spent before selecting another exact-preserving optimization.

## Closure

`CLOSED_REJECTED_SOLVER_RUNTIME`

HYDTABLE01 remains useful evidence that conductivity lookup is numerically feasible but not a worthwhile standalone performance mechanism in the tested Reference solve.
