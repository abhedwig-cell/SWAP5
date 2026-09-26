# F-PE-APPROX02 A2 result — 1e-4 convergence envelope

Date: 2026-09-26

Status: `REJECTED_COUPLED_ROBUSTNESS`

Candidate:
joint head + compartment/total balance tolerances of `1e-4`, with all other solver controls unchanged.

## Positive evidence

A2 was strongly speed-positive in direct Richards tests.

Across the 12-case B01/B12/O05/O14 wet/mid/dry single-step matrix:

- all cases converged;
- median solver speedup was approximately 56%;
- worst relative head deviation was approximately `5.34e-5`;
- worst relative bottom-flux deviation approximately `5.21e-5`;
- worst relative water-content deviation approximately `1.42e-5`.

On a 20-step direct accepted-state trajectory at `1e-3 d`:

- median speedup across 12 material/regime cases was approximately `49.7%`;
- worst relative head error approximately `5.2e-6`;
- worst cumulative bottom-exchange error approximately `1.2e-6`.

The production application steady-sequence gate also preserved exact mass accounting.

## Coupled MODFLOW6 gate

The live SWAP + MODFLOW6 test was run in three independent jobs with the same code and pinned MODFLOW6/Python dependencies.

Result:

- one replica completed and matched the exact coupled endpoint;
- two replicas failed in the A2 arm before the coupling loop at the first SWAP corrector trial with participant status `6` (`TRIAL_FAILED`);
- the exact arm did not show this failure.

The successful replica is insufficient to override the two independent failures.

This is a robustness failure at the chosen approximation envelope.

## Decision

A2 at `1e-4` is rejected as a production-shaped opt-in.

The direct solver frontier remains valid evidence, but production admission requires coupled repeatability.

No production default is changed.

## Handoff

The existing matrix shows a clear safer point:

joint tolerance `1e-6` (the former `1e6` multiplier).

That setting retained approximately 45% median direct solver speedup while the worst single-step state/flux deviations remained around `1e-6` or below.

A separate candidate, A2B, must be preregistered and independently pass multistep, canonical application/mass and replicated live MODFLOW6 gates.
