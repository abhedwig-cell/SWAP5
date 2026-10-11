# F-PE-REPRO02 R13 result — ordered retry causality

Date: 2026-09-26

Status: `TEMPORAL_REJECTION_IS_INITIATING_CAUSE`

## Protocol

The model-certificate transaction executor was instrumented test-only to emit the ordered result of every retry attempt.

Six difficult PROFILE06 origins were tested at:

- -0.001 cm;
- 0;
- +0.001 cm.

Three fresh-process repetitions were used per point with the 48/16/1e-10 physical controls retained from R9-R12.

Each attempt records:

- retry index;
- attempted duration;
- physical solver success/failure;
- nonlinear iterations;
- backtracking attempts;
- temporal certificate availability;
- normalized temporal indicator;
- rejection/acceptance reason.

The first analysis run returned a nonzero process status only because its parser incorrectly assumed that retry indices remain globally monotonic across multiple accepted canonical subtransactions. The raw trace itself was complete and deterministic. A successful accepted subtransaction correctly starts a following canonical transaction with retry index zero again. The parser was repaired without changing measurement instrumentation or execution semantics.

## Result

All six zero-displacement controls were accepted on the first full-duration attempt.

For every one of the 12 signed nonzero points, the **first full-duration attempt physically converged and was rejected by the temporal certificate**.

First-reason census:

- TEMPORAL: 12/12 nonzero points;
- SOLVER: 0/12 nonzero points;
- MASS: 0/12 nonzero points.

The subsequent retry path is regime-dependent but follows the same causal ordering: one or more temporal rejections at reduced duration are followed by nonlinear solver failures for the 11 points that ultimately fail.

Representative deterministic sequences:

- B01 mid -0.001 cm:
  - 1.0e-4 day: TEMPORAL, indicator ≈ 2.9725;
  - 5.0e-5 day: TEMPORAL, indicator ≈ 1.5338;
  - 2.5e-5 day and smaller: SOLVER failures through retry exhaustion.

- B01 mid +0.001 cm, the only nonzero participant PASS:
  - 1.0e-4 day: TEMPORAL;
  - 5.0e-5 day: TEMPORAL;
  - a reduced-duration transaction is then accepted;
  - a following canonical subtransaction is accepted and the full requested window completes.

- O14 wet +0.001 cm:
  - 1.0e-4 day: TEMPORAL, indicator ≈ 52.3302;
  - 5.0e-5 day: TEMPORAL, indicator ≈ 42.6580;
  - 2.5e-5 day and smaller: SOLVER failures through retry exhaustion.

- O14 mid -0.001 cm:
  - 1.0e-4 day: TEMPORAL, indicator ≈ 23.5970;
  - 5.0e-5 day: TEMPORAL, indicator ≈ 14.9683;
  - 2.5e-5 day and smaller: SOLVER failures through retry exhaustion.

No first-attempt mass rejection was observed.

## Causal correction to R1

R1's status `LOCALIZED_TO_NONLINEAR_SOLVER_BEFORE_TEMPORAL_GATE` is superseded.

R1 inspected the serialized backend's final physical observation after the transaction had exhausted retries. That final observation correctly showed a nonlinear solver failure and no temporal evaluation, but it did not represent the first attempt in the retry chain.

R13 establishes the actual order:

1. full-duration physical solve converges;
2. temporal certificate rejects the converged candidate;
3. transaction duration is reduced;
4. repeated reduced-duration attempts eventually enter a nonlinear failure regime;
5. retry budget is exhausted for 11/12 nonzero points.

Therefore nonlinear failure is a **downstream retry-path consequence**, not the initiating rejection mechanism.

## Interpretation

The difficult-origin participant frontier collapses because the current temporal model-certificate policy rejects tiny nonzero coupling perturbations at the full coupling-window duration. The generic retry policy then moves the solve into shorter-duration regimes where the current prescribed-head Richards path can become much harder or fail entirely.

This is not evidence that the temporal certificate is mathematically wrong. It establishes that the interaction between:

- the temporal indicator and its 1e-5 cm budget;
- retry-scale policy;
- prescribed-head perturbation;
- and short-duration nonlinear behavior

is the controlling numerical-policy surface.

## Decision

REPRO02 has met its closure criterion.

The first authoritative rejection mechanism is identified well enough to open a separate numerical-policy study. No production defect repair is justified directly from REPRO02, and APPROX04 must remain closed.

Recommended handoff:

`F-PE-TEMPORAL02 — difficult corrector temporal-certificate / retry-policy frontier`

That workunit should determine whether the current temporal budget and retry policy are appropriate for same-origin coupled correctors, and whether an alternative qualified policy can preserve hydrological fidelity while avoiding the temporal-to-nonlinear failure cascade.

No production `src/**` change is authorized by R13.
