# F-MACRO-TRACER01-D1 — timestep refinement preregistration

Date: 2026-10-01

Status: PREREGISTERED_BEFORE_REFINEMENT_RUN

Case: SPECHTACKER_ECHORD_FIXTURE (software composition only)

## Purpose

Check that the accepted-state flux reconstruction plus donor-cell conservative tracer result is not a coarse-substep artifact.

## Frozen runs

Run the exact same SWAP5 matrix-only fixture with nominal accepted-step targets:

    120 s
     60 s
     30 s

Solver retry logic remains fail-closed and may reduce a step only for convergence.

## Metrics

For each run record:

- accepted packet count;
- retry count;
- global tracer residual;
- maximum observer bottom-flux residual;
- final normalized tracer profile.

Compare:

    L1_120_60 = sum |M120_i - M60_i| / M_input
    L1_60_30  = sum |M60_i  - M30_i| / M_input.

## Qualification rule

Require:

1. exact tracer closure at floating-point scale for all runs;
2. observer bottom-flux closure at numerical roundoff/solver-balance scale;
3. L1_60_30 <= L1_120_60 (refinement is convergent rather than divergent);
4. L1_60_30 <= 0.02 as a practical research-reference tolerance.

No dispersive term or RFM parameter may be added if this gate fails.
