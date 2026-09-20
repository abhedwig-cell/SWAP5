# F-ROM-LARE BC2-C6J FEMO mathematical qualification closeout

## Decision

**The current FEMO realization is not mathematically qualified over the frozen B14 moment domain. No free-running FEMO is authorized.**

C6J remains fully response-free. It generated no hydrological trajectory and changed neither Reference Richards, RossFast nor production groundwater coupling.

## Authority

The nine scientific shards were executed under the frozen C6J authority in run `35530325107` at head `14e333ef...`.

The original aggregate job failed only because it assumed all boundary operators would exist even when upstream local-manifold gates failed. The nine shard artifacts were preserved unchanged. Aggregation-only recovery run `35530564614` at head `b76fb1c4...` reused those immutable artifacts and produced the authoritative aggregate.

Artifact: `10611380500`

Result SHA-256: `5c0682fc3fde0318331727d34e7613faa2c70598ed79c3684b3f4a8445dee88d`.

## Result

All 126 frozen S/M targets remain physically realizable.

The preregistered interior affine-suction numerical realization nevertheless fails the broad qualification contract:

- local all-start convergence: 38/126 state cases;
- local profile uniqueness: 4/126;
- interior bounded profile: 38/126;
- independent S/M recovery: 26/126;
- local moment Jacobian gate: 38/126;
- qualified global Onsager metric: 4/126.

Only four C6C head-state cases generate qualified metric/operator states, yielding four generated head operators out of 168 expected. Six flux operators are generated out of 126 expected.

Where operators are generated, their linear stationarity/constraint residuals are extremely small. The blocker occurs earlier, in robust realization of the local moment manifold.

## What the failure means

This does **not** invalidate the Richards energy-dissipation identity, strict capillary-energy convexity or the physical interpretation of S and M.

Many nonzero-moment states have a valid interior affine-suction solution from at least one frozen start, while other frozen starts begin outside the admissible suction interval and remain on the preregistered invalid-trial penalty.

Even some zero-moment cases fail the frozen coefficient-agreement tolerance while producing almost indistinguishable water-content profiles.

So C6J is not evidence that the physical convex energy problem is intrinsically multivalued. It is evidence that the **specific prospectively frozen numerical realization is not robust enough** to serve as the ROM map over the complete domain.

## Stop rule

C6J explicitly forbids repairing this outcome by:

- selecting only the successful starts;
- relaxing the frozen agreement tolerances;
- adding an active-bound/obstacle solver after seeing the failures;
- changing state scaling;
- regularizing the Onsager metric;
- moving directly to a free-running or blind FEMO test.

The current FEMO route therefore stops here.

## Scientific boundary

The accumulated evidence now separates the physical-state question from the reconstruction question.

The centered first moment remains a meaningful conservation-derived shape state, and both C6D and C6I show why additional vertical asymmetry information is scientifically relevant. But C5Z, C6E and C6J show repeatedly that turning a very small state vector into a universally robust hydraulic subgrid representation is itself the hard problem.

The next decision is therefore strategic rather than automatic: either open a **new**, independently justified convex/obstacle moment-realization family before response, or stop searching for a universal very-low-dimensional replacement and return to purpose-dependent sufficiency of the already-qualified simpler Layer-ROM frontier.
