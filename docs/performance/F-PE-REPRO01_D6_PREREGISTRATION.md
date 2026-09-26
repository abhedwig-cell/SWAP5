# F-PE-REPRO01 D6 — mode-5 directional poisoned-workspace equivalence

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

The existing ZERO-WASTE01 poisoned-workspace gate proves overwrite-before-read behavior for direct Reference solves with bottom modes 2 and 7.

It does not cover the failing production seam:

- bottom mode 5;
- accepted-step directional service requested;
- TRIDAG factorization capture active;
- FGC44 first corrector trial.

Valgrind also traces undefined bytes back to Reference workspace allocation on this directional path.

## Question

Is the exact mode-5 accepted-direction physical solve independent of prior Reference scratch contents?

## Protocol

Build two test-only binaries from the same production source:

1. CLEAN
   - unchanged backend.

2. POISON
   - test-only backend instrumentation calls
     `ensure_reference_workspace_shape` and `poison_reference_workspace`
     immediately before `solve_with_accepted_step_direction`.

No production source file is edited.

Run 100 fresh first-corrector processes per binary using the same exact/default FGC44 request.

## Required equivalence

POISON must match CLEAN in:

- trial success;
- solver status;
- nonlinear/Jacobian/linear/backtracking counts;
- q;
- temporal certificate availability and head bound.

If POISON fails or differs while CLEAN succeeds, the directional mode-5 seam has a deterministic dependency on prior scratch contents and a separate repair workunit is justified.

If CLEAN and POISON are bit-identical, Valgrind's undefined bytes are not sufficient evidence of an active scratch dependency and REPRO01 continues elsewhere.

No production repair is made in D6.
