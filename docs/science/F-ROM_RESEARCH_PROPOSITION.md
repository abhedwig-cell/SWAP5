# F-ROM research proposition authority

## Status

**RESEARCH AUTHORITY. NOT STATUS-A. NOT A PRODUCTION SOLVER COMMITMENT.**

This document freezes the governing proposition for the SWAP5 reduced-order soil-water research track.

It supersedes the earlier F-ROM01 framing that moved too quickly from state-reduction research toward a candidate third solver. The earlier work remains historical evidence. In particular, the direct `reference_richards_legacy_solver_t%solve` history-collision pilot is not a scientific baseline and must not be tuned into one.

Clean-sheet rule: **no source-code inheritance from MetaSWAP or the 2026 Sequential Steady State prototype; no algorithmic inheritance unless independently justified; full knowledge inheritance is permitted.**

Reference Richards remains the full-order scientific reference inside the admitted SWAP physics. RossFast remains the admitted alternative numerical route. Neither implies that a reduced-order production solver should exist.

## Frozen proposition

Primary scientific question:

> **Can the future-relevant information in physically reachable SWAP Richards states be represented by a small, practically useful state without losing the input-output distinctions required by a declared SWAP capability and forcing domain?**

Separate engineering/value question:

> **If such compression exists, can that state be propagated conservatively, robustly and more efficiently than the relevant alternatives, including Reference Richards, RossFast and conventional spatial coarsening?**

A third soil-water solver is an allowed outcome, not the required outcome.

## What is being reduced

The target is not the number of numerical Richards nodes by itself. A finely discretized Richards column contains numerical degrees of freedom and physical prognostic information. F-ROM asks whether the latter occupies a much smaller effective state space over the reachable domain relevant to SWAP.

The useful reduction is: `full accepted physical state -> compact future-relevant information` for a declared capability.

## Predictive equivalence and ambiguity

Let `x` denote an accepted full-order Richards state, `U` an admissible future forcing/boundary sequence and `Y` the outputs required by the capability contract.

Two reachable states are predictively equivalent for that contract when they cannot be materially distinguished by the relevant future outputs under the admissible future probes. A reduced projection `P(x)=z` is insufficient when it maps two non-equivalent full-order states close together while identical future probes produce materially different outputs.

ROM-1 will therefore estimate output-specific predictive ambiguity: how far future outputs can separate when the reduced representation says the starting states are nearly the same.

Evidence is always bounded to the preregistered reachable states and future-probe set. No finite experiment is presented as proof over all mathematically possible forcings.

The core ROM-1 evidence product is `representation complexity -> predictive ambiguity`, with the numerical Reference floor shown separately.

## Minimum state is conditional

There is no universal minimum state independent of the problem definition. Required representation depends on parameter/material domain, forcing/boundary domain, temporal bandwidth, required outputs/capabilities, prediction horizon and accepted error envelope.

Consequently F-ROM may establish different qualified state requirements for different capabilities. Groundwater coupling sufficiency does not automatically imply full crop-water, oxygen-stress or solute-transport sufficiency.

## Practically useful state class

F-ROM does not minimize state dimension over arbitrary mathematical encodings. A candidate state is useful only if it is plausibly compatible with a solver.

Candidate coordinates are assessed for:

- predictive sufficiency within the declared domain;
- robustness and continuity under small physical perturbations;
- physical validity and boundedness;
- explicit persistence and restartability;
- conservative accounting, with total water storage or an equivalent exact accounting constraint;
- practical projection from accepted state;
- practical future propagation without first reconstructing and solving the full Richards problem;
- semantics that can be tested for transfer across contrasting materials.

An abstract coordinate may be acceptable, but a low-dimensional encoding that merely stores a full profile implicitly is not.

## State first, closure second

F-ROM separates state sufficiency, closure and reconstruction/process observation.

ROM-1 addresses state sufficiency without fitting a reduced dynamics law. Only if ROM-1 establishes a useful state does ROM-2 compare closure classes at a fixed state definition.

No closure is allowed to compensate for a demonstrably insufficient state by hidden history, correction fluxes or untracked side state.

## Reference authority before projection evidence

Reference Richards is numerical reference behaviour, not mathematical truth.

Before ROM projection errors are interpreted, ROM-0 must establish the relevant numerical Reference floor through qualified accepted trajectories and controlled resolution/timestep sensitivity.

Evidence must keep separate: `E_numerical_reference`, `E_projection_information_loss`, `E_closure` and `E_reconstruction_process`.

A ROM discrepancy below the demonstrated Reference resolution floor is not automatically scientifically meaningful.

## Accepted trajectory authority

ROM experiments use **accepted SWAP5 Reference-Richards trajectories**, including the admitted attempt, retry, timestep and commit lifecycle.

A single direct solver attempt is not the trajectory authority. Research code may observe accepted states and diagnostics, but it must not bypass state ownership and then reinterpret non-convergence of one attempt as failure of the physical reference trajectory.

## Reachable-state principle

State identification uses physically reachable accepted states generated under declared forcing and boundary histories.

The library contains both realistic histories representative of the target use case and controlled/adversarial excitations intended to expose hidden future-relevant modes.

Low dimension observed only because the system was weakly excited is insufficient evidence.

## Counterexample-driven enrichment

ROM-1 begins with deliberately simple fixed-coordinate projections. Complexity is added only after a reproducible held-out counterexample demonstrates missing information.

Sequence: simple projection -> find near-collision -> branch under multiple identical future probes -> identify output ambiguity -> inspect the full-state difference -> add one physically motivated descriptor -> retest on held-out histories, collision pairs and probes.

Explicit memory variables are not introduced merely because histories differ. They become candidates only after compact instantaneous descriptors fail to remove reproducible predictive ambiguity.

## Fixed soil coordinates first

Early hydraulic projections use fixed depth bands, not a moving crop-root-zone boundary. Dynamic root depth is an external/process variable. Root-zone quantities may later be observed or reconstructed for process-sufficiency tests.

## Comparators

A useful reduced-order claim must be challenged against more than full-resolution Reference Richards:

- Reference Richards as full-order scientific reference;
- RossFast as the current alternative numerical route;
- conventional spatially coarsened Richards where a scientifically consistent comparator can be constructed;
- an a-priori integrated/two-layer reduced formulation as literature comparator where appropriate.

A specialized ROM that does not improve the relevant cost-error or information-retention frontier over simple spatial coarsening does not justify its additional complexity.

## RossFast performance boundary

The canonical F-ROSS24 characterization is relevant proposition evidence, not a universal runtime claim.

On its bounded 213 paired-valid E0 cases, GitHub-hosted screening reported mean RossFast/Reference solver CPU ratio about 0.823, corresponding to about 17.7% lower solver CPU and mean Reference/RossFast speedup about 1.216. The broader child CPU/wall measurements improved by about 4.36%.

These are explicitly screening results on the F-ROSS24 measurement boundary, not formal whole-model or large-MultiSWAP performance claims.

Therefore ROM computational value must be demonstrated on a declared target workload rather than inferred from state dimension alone.

## Conservation and long-horizon drift

Any future ROM must make the water ledger explicit. The design preference is to carry total storage directly or enforce an equivalent exact accounting relation so approximation resides in hydraulic/process closure rather than hidden water-balance correction.

A correction flux introduced only to conceal structural accumulated mass error is not acceptable. Short-horizon agreement is insufficient if small systematic flux error creates long-horizon storage drift.

## Validity and fail-closed behaviour

A future reduced solver need not cover every SWAP state. Its qualified domain must be explicit in the joint space of state, forcing, boundary conditions, parameters and capability.

`OUTSIDE_QUALIFIED_DOMAIN` is an acceptable outcome. Adding accumulating special cases merely to avoid leaving the reduced domain is a stop signal, not automatic progress.

## Research stages

ROM-P: proposition qualification.
ROM-0: accepted full-order trajectory and Reference-floor authority.
ROM-1A: reachable-state library.
ROM-1B: predictive-state ambiguity tests.
ROM-1C: counterexample-driven state enrichment.
ROM-1X: cross-material transfer.
ROM-1D: comparator challenge.
ROM-2: closure identification, only after a positive ROM-1 gate.

Frequency response, POD/modal analysis, equilibrium manifolds and explicit memory models remain optional diagnostic tools. They are not prerequisites and may not determine the architecture before simpler predictive-state evidence exists.

## Production gate

No production reduced-order solver work is authorized by this research authority alone.

A transition to ROM-2 requires evidence that a small practical state materially reduces predictive ambiguity above the Reference floor, transfers across the preregistered contrasting-material challenge, survives held-out histories/probes, and is not merely equivalent to an equally effective simple coarse-Richards discretization.

Production-solver design requires an additional later value/performance gate against the then-current RossFast and target workload.

## Valid negative outcomes

`NO_USEFUL_STATE_COMPRESSION`, `COARSE_RICHARDS_SUFFICIENT`, `MATERIAL_SPECIFIC_ONLY`, `CAPABILITY_TOO_NARROW`, `CLOSURE_NOT_COMPUTATIONALLY_COMPETITIVE`, and `ROSSFAST_SYSTEM_VALUE_DOMINATES` are valid scientific conclusions.

F-ROM exists to discover the right answer, not to guarantee a new solver.
