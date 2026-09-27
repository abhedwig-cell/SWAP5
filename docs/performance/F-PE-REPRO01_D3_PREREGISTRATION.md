# F-PE-REPRO01 D3 — compiler-initialization sensitivity

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

D2 reproduced an exact/default first-corrector failure with no MODFLOW/XMI involvement.

The failure is rare and process-dependent, while reported predictor inputs are identical between pass and fail.

This pattern is consistent with, but does not prove, undefined or uninitialized local/runtime state.

## Question

Does the exact first-corrector failure frequency change materially under compiler modes that force local initialization or runtime checking?

## Builds

Compile the same exact D1 probe in three diagnostic modes:

1. DEFAULT
   - existing production-like `-O2` flags.

2. ZERO_INIT
   - existing flags plus `-finit-local-zero`.

3. SNAN_CHECK
   - existing flags plus:
     - `-finit-real=snan`;
     - `-finit-integer=-999999`;
     - `-fcheck=all`;
     - `-ffpe-trap=invalid,zero,overflow`.

These flags are diagnostic only and are not production recommendations.

## Execution

For each successfully compiled build, run 100 fresh exact/default processes of:

`initialize -> first trial(href)`

Record:

- process success/failure;
- participant trial status;
- backend solver status;
- nonlinear/backtracking/retry counts;
- process exit signal/error for trapped runs.

## Interpretation

Evidence for uninitialized-state sensitivity includes either:

- DEFAULT reproduces intermittent status 6 while ZERO_INIT removes it;
- SNAN_CHECK traps or reports invalid use before the corrector completes;
- or diagnostic modes change the failure signature in a repeatable way.

If all three modes exhibit comparable intermittent status 6 without runtime-check diagnostics, shift D4 toward transaction/workspace state ownership rather than generic uninitialized locals.

No production source change is admitted by D3.
