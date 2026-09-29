# F-PE-ELASTIC47 — ELAS × timestep interaction preregistration

Date: 2026-09-29

Status: PREREGISTERED_RESEARCH

Parent:
`F-PE-ELASTIC46 — QUALIFIED_PRODUCTION_SHAPED_RESEARCH_RESULT`

Parent postimage:
`research/f-pe-elastic46-production-effect@19681b9e0c38f200e690aab2c6a0c5442b974371`

Canonical authority at start:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Question

ELASTIC46 showed a strong but non-monotonic interaction between elastic
storage and nonlinear work in difficult saturated fixed-interval trials.

ELASTIC47 asks a narrower production-shaped question:

> Does physically parameterized ELAS shift the largest interval that the
> existing Reference/full-half transaction path can complete under the same
> forcing perturbation, and if so does that shift reduce end-to-end work and
> runtime?

Three regimes remain frozen:
1. `OFF`;
2. `FIXED_1E6`: uniform `Ss = 1e-6 cm^-1`;
3. `GENERATED`: admitted BOFEK/BRO generated prior for profile `90116260`.

No solver, convergence, timestep-controller or ELAS policy is changed.

## Frozen source/profile

Use the same admitted frozen BRO authority as ELASTIC46:
- producer run `36550782840`;
- artifact `f-pe-elastic12a4-pdok-atom`;
- SHA-256 `f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6`;
- profile `90116260`;
- RD point `179362.75550490862, 418659.84937244334`.

Use exactly the ELASTIC46 16-node variable grid and the same hydraulic MvG
fixture. Only ELAS regime, initial saturated head, flux perturbation and
requested interval duration vary.

## Matrix

Initial pressure head:
- `+0.1 cm`;
- `+2 cm`;
- `+10 cm`.

Top-flux perturbation relative to equilibrium:
- `+0.05 cm/day`;
- `-0.05 cm/day`;
- `+0.025 cm/day`;
- `-0.025 cm/day`.

Requested interval duration:
- `0.25 day`;
- `0.125 day`;
- `0.0625 day`;
- `0.03125 day`;
- `0.015625 day`.

For every state/forcing/duration combination run all three ELAS regimes with
identical numerical settings.

Total frozen matrix:
`3 × 4 × 5 × 3 = 180` production-shaped cases.

## Observations

For every case record:
- completed and committed;
- kernel status;
- accepted substeps;
- solver iterations;
- nonlinear iterations;
- internal retries;
- backtracking attempts;
- Jacobian builds;
- linear solves;
- HeadCalc calls;
- complete mass ledger and residual for completed cases.

For each state × forcing × regime determine the **largest completed duration**
from the frozen ladder. This is a bracketed completion threshold, not an
estimate of an exact mathematical stability limit.

Also record total work over the ladder:
- summed nonlinear iterations;
- summed retries;
- summed backtracking attempts;
- summed HeadCalc calls.

## Dynamic matched timing rule

For each state × forcing pair for which all three regimes have at least one
completed duration, choose the **largest duration completed by all three**.

At that common duration:
- time each regime in the same executable and environment;
- use at least 5 replicas;
- use identical repeated-call count and warmup;
- create a fresh committed state for every repeated interval so each timed call
  is semantically independent;
- report raw medians and ratios.

If no common completed duration exists, no timing claim is made for that pair.

## Hypotheses

H1. ELAS shifts the completion threshold in at least part of the saturated
matrix.

H2. The sign and magnitude of the threshold shift are state/forcing dependent;
no monotonic universal benefit is assumed.

H3. GENERATED and FIXED_1E6 are not interchangeable threshold surrogates.

H4. Where ELAS admits a larger common production interval or sharply reduces
work at the same completed interval, the resulting end-to-end runtime effect is
large enough to dominate the approximately 1.6% trivial-equilibrium ELAS
overhead observed in ELASTIC46.

## Gates

A1. Generated prior preparation is identical to ELASTIC46 and finite positive.

A2. All 180 matrix cases execute and are retained, including explicit
non-completed results.

A3. Every completed case passes the existing hard mass gate.

A4. Threshold extraction is deterministic from the frozen duration ladder.

A5. No regime-specific duration or perturbation tuning.

A6. Matched timing, when available, uses the same state, forcing, duration,
call count and warmup across regimes.

A7. O0/O2 non-timing classifications and counters agree.

A8. No `src/**` production change.

## Decision rule

ELASTIC47 is a research workunit only.

A positive result may justify a later production timestep-policy study only if
the threshold/runtime interaction is repeated and bounded. It does not by
itself authorize:
- default-on ELAS;
- `Ss = 1e-6` as default;
- a new timestep controller;
- changed tolerances;
- changed solver/globalization policy.
