# F-PE-TEMPORAL03 P2 — independent fixed-substep Reference oracle

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

## Purpose

Create an independent temporal error authority for dynamic-history correctors.

The oracle must not use the model temporal certificate or candidate budget under test.

## Origin

Use the P0 physical dynamic-origin construction:

- Reference-floor history step;
- nonzero predecessor derivative derived from physical state change;
- complete mass accounting.

For oracle integration, snapshot the resulting physical state and rematerialize it as a plain committed physical state at the dynamic-origin time. This deliberately removes temporal-certificate continuation from the oracle while preserving the exact same physical initial state.

## Corrector forcing

Use the same mode-5 prescribed bottom-head target and top/source-sink forcing as the participant corrector.

## Fixed subdivision levels

Integrate the full 1e-4 day corrector window with equal fixed Reference-floor substeps:

- N = 8;
- N = 16;
- N = 32.

Every substep must:

- converge physically;
- have complete mass accounting;
- commit only the floor candidate into the private oracle state.

No adaptive retry or temporal acceptance criterion is allowed.

## Initial qualification set

Use a bounded but difficult dynamic subset before expanding:

- B01 wet;
- O05 wet;
- O14 wet;
- O14 mid;

with both +/-10% history directions and corrector offsets +/-0.001 and +/-0.01 cm.

## Oracle convergence metrics

Compare 8→16 and 16→32:

- max terminal |dh|;
- max terminal |dtheta|;
- terminal bottom flux;
- integrated bottom exchange;
- aggregate mass residual.

## Oracle acceptance gate

The N=32 state can act as provisional refined authority only when 16→32 is no larger than 8→16 for the principal state/flux metrics and all levels remain physically converged and mass-complete.

If refinement is nonconvergent or enters a solver pathology, stop and classify the affected point rather than silently using N=32 as truth.

## Candidate comparison

Candidate temporal budgets are compared only after oracle convergence is established.

No production source change is allowed.