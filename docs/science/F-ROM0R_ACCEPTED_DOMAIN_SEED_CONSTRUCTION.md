# ROM-0R Accepted-Domain Seed Construction

## Status

**PREREGISTERED RESEARCH. NOT STATUS-A. NOT ROM-1.**

ROM-0R is the successor to the closed ROM-0 laboratory decision `EXPAND_ACCEPTED_TRAJECTORY_DOMAIN`.

Its sole purpose is to establish analytically consistent, accepted Reference-Richards seed trajectories from which later controlled perturbation and Reference-floor experiments can be constructed.

It does not test state compression.

## Why a successor is required

The first ROM-0 matrix started from a uniform-pressure profile but treated zero external flux as a hold condition. In a gravitational Richards column that profile is not zero-flux equilibrium.

All frozen cases failed the accepted transaction in their first requested interval, while an independent existing accepted-runtime control passed.

ROM-0R therefore changes the experiment construction, not the production solver.

## R1 hypothesis: gravity-consistent steady seed

For a homogeneous column with uniform pressure head `h0`, the internal total-head gradient is the unit gravitational gradient.

With the current SWAP sign convention, the corresponding steady water flux used by the admitted FMR44R reference fixture is:

```text
q_eq = -K(h0)
```

The R1 seed therefore uses:

```text
h_i = h0 for all nodes
theta_i = theta(h0)
q_top = q_eq
q_bottom = q_eq
bottom mode = prescribed flux (2)
```

No source/sink processes are active.

The expected exact physical property is constant storage, not zero flux.

## Frozen R1 material/state domain

R1 uses the already selected contrasting fixtures:

- B01
- B14

For both materials:

```text
effective saturation Se = 0.85
geometry = 16 x 10 cm
depth = 160 cm
observation interval = 0.0016 day
requested intervals = 8
```

The shorter eight-interval seed is deliberate: R1 is an accepted-domain construction, not yet a long transient experiment.

The same frozen Reference numerical controls from ROM-0 remain unchanged.

## R1 acceptance

A material seed passes only when all eight requested observation intervals:

- complete through the accepted FMR/kernel/canonical Reference lifecycle;
- commit exactly one external revision per observation interval;
- have complete mass accounting within the existing hard mass gate;
- preserve finite pressure head and water content;
- preserve storage within the measured numerical roundoff/envelope of the seed execution;
- retain the prescribed top and bottom steady flux identity within the existing published contract.

No forcing or numerical parameter is changed after observing R1.

## Independent control

The existing admitted FMR44R serialized Reference runtime fixture is executed unchanged as an independent control.

A failure of that fixture blocks interpretation of R1.

## R2 is not authorized by R1 preregistration

R1 deliberately does not preregister transient perturbation amplitudes.

If both B01 and B14 R1 seeds are accepted, a new repository checkpoint must define R2 perturbations before their execution.

R2 will perturb accepted R1 states, rather than recreate arbitrary initial profiles.

A preferred construction is dimensionless perturbation of the analytically defined steady flux or hydraulic gradient, with discovery and holdout amplitudes frozen before execution.

## Close decisions

R1 closes as one of:

```text
PROCEED_TO_ROM0R_R2_PERTURBATION_PREREGISTRATION
EXPAND_ACCEPTED_SEED_CONSTRUCTION
BLOCKED_ACCEPTED_RUNTIME
NO_GO_B01_B14_ACCEPTED_SEED
```

R1 cannot authorize ROM-1A.
