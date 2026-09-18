# ROM-0 qualification adjudication

## Decision

**EXPAND_ACCEPTED_TRAJECTORY_DOMAIN**

ROM-0 does not authorize ROM-1A.

The preregistered B01/B14 laboratory produced no accepted trajectory points, so it cannot establish the numerical Reference floor required for state-compression experiments.

## What the execution established

The final qualifying execution used the frozen 18-case matrix after build/harness defects had been repaired. An independent existing accepted-runtime fixture was executed first and passed. This separates the ROM-0 experiment-domain result from a general failure of the FMR/kernel/canonical lifecycle.

All eighteen preregistered B01/B14 cases then failed in their first requested observation interval. The common terminal signature was transaction retry exhaustion. The last Reference attempt reported `legacy-reference-retry`, reached the frozen sixteen nonlinear iterations, and did not fail the external mass gate.

No accepted B01/B14 state was therefore recorded and the exact replay was correctly not attempted.

## Comparison with existing solver-seam evidence

This result does not mean that B01 and B14 at effective saturation 0.85 are intrinsically invalid Reference Richards cases.

F-ROSS24 already contains direct solver-seam evidence for the same two materials, the same 16 by 10 cm geometry, the same 0.0016-day solve duration, and the same NOMINAL/DRYING fixed-flux factors. Those direct Reference cases were route-valid.

The new evidence therefore identifies a narrower problem: the frozen ROM-0 starting-state/forcing contract does not yield an accepted transactional trajectory under the frozen full/half and retry policy.

## Physical diagnosis used only for successor design

The original ROM-0 state used uniform pressure head at Se=0.85. Uniform pressure head is not hydrostatic in a gravitational field. It carries the unit gravitational hydraulic gradient.

Consequently `E0_HOLD`, which imposed zero top and bottom flux, was not actually a steady hold experiment.

The independently admitted FMR44R equilibrium fixture illustrates the consistent alternative: for a uniform pressure-head profile it sets both boundary fluxes to the gravity-driven steady flux `-K(h)`.

This observation is not used to retune the failed matrix. The matrix remains failed evidence. It is instead the physical basis for a new ROM-0R preregistration.

## Scientific boundary

ROM-0 has not tested a reduced state.

There is no result yet for predictive ambiguity, effective state dimension, memory, closure, coarse-Richards comparison, or ROM performance.

The only permitted next step is to construct a valid accepted Reference trajectory domain and then re-establish the numerical Reference floor.

## Successor rule

ROM-0R starts from analytically consistent seed states and boundary conditions chosen before execution.

It must first demonstrate accepted seed trajectories without changing production physics or canonical numerical ownership. Perturbation experiments are a later separately preregistered step.

Failure of a preregistered seed is retained as evidence. Parameters are not iteratively tuned until a seed happens to pass.
