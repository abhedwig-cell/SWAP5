# F-PE-REPRO01 D4 — fixed-binary runtime-layout sensitivity

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

The exact first-corrector failure is reproducible but rare:

- D2 N produced 1/40 failures on two independent workflow runs;
- the failing signature is solver `SW_SOLVE_RETRY_ADVISED` after 16 nonlinear iterations, 108 backtracking attempts and one internal retry;
- D3 default, zero-init and sNaN/check builds each produced 100/100 PASS.

Therefore D3 did not establish a compiler-initialization cause, and a larger fixed-binary sample is needed before comparing failure frequencies.

## Question

Does exact first-corrector failure frequency depend materially on OpenMP/runtime controls when the compiled binary is held fixed?

## Protocol

Compile the exact/default D1 probe once with the ordinary production-like build flags.

Use that same shared library for four execution environments, 500 fresh processes each:

- DEFAULT: no additional OpenMP environment controls;
- OMP1: `OMP_NUM_THREADS=1`;
- OMP1_STATIC: `OMP_NUM_THREADS=1`, `OMP_DYNAMIC=FALSE`;
- OMP1_BIND: `OMP_NUM_THREADS=1`, `OMP_DYNAMIC=FALSE`, `OMP_PROC_BIND=TRUE`.

Every process performs only:

`initialize -> first trial(href)`

No MODFLOW, A1 or A2C.

## Metrics

Per environment:

- PASS count;
- trial-status failure count;
- process failure count;
- failure solver-status histogram;
- nonlinear/backtracking/retry signature for the first observed failure.

## Interpretation

The main purpose is to estimate whether the rare exact failure persists at larger sample size.

A runtime-control effect is considered credible only if:

- failures occur in DEFAULT at a nonzero rate;
- and one controlled environment changes that rate materially across 500 trials.

Zero failures in all 2000 trials would classify the issue as build/context sensitive rather than establishing that the defect is gone.

No production runtime recommendation is admitted by D4.
