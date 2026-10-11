# F-PE-REPRO02 R13 — per-attempt rejection-order trace

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

R1 and later summaries report failed participant trials with final solver status `retry-advised` and temporal indicator `not run`.

That observation is the final serialized physical observation after the transaction has exhausted retries. It does not establish that nonlinear solver rejection was the first cause in the retry sequence.

The aggregate transaction diagnostics for the same failures contain both:

- temporal rejections;
- solver rejections.

The model-certificate transaction algorithm retries at a reduced duration after either rejection. Therefore an initial physically converged attempt may be rejected by the temporal certificate before later shorter attempts fail in the nonlinear solver.

This causal order must be resolved before REPRO02 can classify the defect or policy boundary.

## Question

For each difficult-origin +/-0.001 cm transaction, what is the ordered rejection sequence across retry attempts?

## Method

Use test-only instrumentation of the model-certificate transaction executor.

Do not change acceptance logic, retry scale, solver configuration, state, forcing or production source.

For every retry attempt record, in order:

- retry index;
- attempted duration;
- physical solver success/failure;
- nonlinear iterations;
- backtracking attempts;
- mass acceptance result when solver succeeds;
- temporal certificate availability;
- normalized temporal indicator;
- temporal acceptance result;
- resulting retry reason: solver, mass, temporal, or accepted.

The trace must be emitted before the next retry changes duration.

## Cases

Primary:

- six difficult PROFILE06 origins;
- offsets -0.001 and +0.001 cm;
- three fresh-process repetitions.

Include zero displacement as a PASS control if inexpensive.

Use the same 48/16/1e-10 controls used by R9-R12.

## Decision

If the first attempt converges and is rejected temporally before later solver failures, REPRO02 must revise the earlier causal statement: temporal acceptance is the initiating rejection and nonlinear failure is a downstream retry-path consequence.

If the first attempt itself fails physically for the failing points, the current nonlinear-first interpretation is retained.

If order differs by case/sign, preserve the regime split.

No production `src/**` change is allowed in R13.
