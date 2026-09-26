# F-PE-REPRO02 R10 — attempt-context involvement

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

R9 established a deterministic split:

- serialized reference-floor physical advance: 18/18 PASS;
- normal canonical transaction route: 7/18 PASS.

The same physical backend, origin, forcing and generous 48/16/1e-10 solver controls therefore diverge only when the canonical transaction lifecycle is active.

For the simple difficult-origin fixture there are no active drainage, thermal or surface-water attempt-context carriers. The remaining reason the serialized model requests attempt context is the accepted-trajectory direction request used by the FGC44 corrector.

## Question

Does canonical attempt-context capture/restore participate causally in the physical-solver divergence?

## Arms

Use the normal exact FGC44 participant route in both arms, with:

- same predictor and committed origin;
- same mode-5 forcing;
- accepted-trajectory direction still requested exactly as in production;
- max nonlinear iterations = 48;
- max backtracking = 16;
- minimum step duration = 1e-10 day.

### BASE

Unmodified serialized transaction behavior.

### NO_CONTEXT

Test-only serialized-backend copy returns `attempt_context_required = .false.` while leaving the physical request and accepted-direction request unchanged.

This disables only canonical attempt-context capture/restore for the diagnostic process. It does not alter production source.

## Cases

Six difficult PROFILE06 origins at:

- -0.001 cm;
- 0;
- +0.001 cm.

Three fresh-process repetitions per point/arm.

## Measurements

Record:

- participant status;
- solver status;
- nonlinear iterations;
- backtracking attempts;
- transaction attempts/retries/solver rejections where exposed;
- final tangent availability on successful trials.

## Decision

If NO_CONTEXT restores convergence for the nonzero failures while BASE reproduces R9, attempt-context handling is causally implicated. A following discriminator must then separate capture from restore and identify the mutated hidden state.

If both arms fail identically, attempt-context handling is excluded and the next target is checkpoint/state cloning or another canonical pre-advance lifecycle operation.

If BASE no longer reproduces R9, stop and reconcile the harness before interpretation.

No production `src/**` modification is allowed in R10.
