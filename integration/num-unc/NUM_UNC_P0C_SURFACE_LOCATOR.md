# NUM-UNC P0C surface-transition locator freeze

Date: 2026-09-19
Stage: C0, transition location only
Baseline: `integration/f-ci-canonical@187e30153c890151768e929170d14bb22af1d86d`

## Purpose

C0 locates and freezes the B01 transition between a non-ponded surface-flux trajectory and a trajectory with a ponding event. It uses only numerical configuration N0. It is not allowed to execute N1 or compare N0 against N1.

This separation is deliberate. Case selection must be independent of the numerical realization that will later be used to test inference invariance.

## Fixed physical case

Material is B01 on 16 homogeneous cells of 10 cm.

Initial effective saturation is fixed at `Se=0.85`. This is the middle state stratum already used prospectively in PUB-P2E08. It is chosen instead of `Se=0.98` to avoid deliberately centring NUM-UNC discovery on the prior stratum with the largest Reference self-disagreement.

The uniform initial pressure head is obtained by inversion of the same van Genuchten retention relation represented by the canonical B01 parameters. Initial water content is then evaluated by the canonical constitutive provider.

The lower boundary is prescribed flux with `qbot=0 cm/day`.

Root uptake, drainage, irrigation, snowmelt, runon and evaporation are inactive.

The surface configuration is:

- ponding maximum: 10 cm;
- runoff resistance: 1 day;
- runoff exponent: 1;
- potential bare-soil evaporation: 0;
- potential pond evaporation: 0.

Any nonzero runoff invalidates the locator case. Runoff is not an endpoint in C0.

## Numerical configuration

Only N0 is allowed:

`dt = 0.0064 day`.

Every physical forcing breakpoint lies exactly on the N0 grid. A solver request for timestep reduction, an internal retry, an alternative linear-solver call, a failed typed integrated-mass gate, or a non-finite state makes that run inadmissible. C0 does not rescue such a run by silently changing its timestep.

This is intentionally stricter than production retry semantics. The purpose is to isolate temporal realization rather than mix the treatment with an endogenous retry schedule.

## Forcing

One forcing block lasts `0.0064 day`.

For a multiplier (m), precipitation during the first eight blocks is

[
P_j = m K_{sat,fit} r_j
]

with

[
r=(0.25,0.50,0.75,1,1,1,1,1).
]

The following eight blocks have zero precipitation.

Total experiment duration is `0.1024 day`.

The same physical breakpoints will later be used by N1, which then takes two 0.0032-day solves inside each N0 forcing block.

## Event definition

A ponding event occurs when any accepted endpoint has

[
pond > 10^{-10} {m cm},
]

matching the current dynamic-top provider's ponding classification scale.

The locator classification is therefore exactly one of:

- `NO_PONDING`;
- `PONDING`;
- `INADMISSIBLE`.

## Search and freeze

C0 first evaluates, in order:

[
m=(0.25,0.5,1,2,4).
]

The first adjacent pair with `NO_PONDING` followed by `PONDING` defines the bracket.

If no such pair exists, C0 closes as `NO_TRANSITION_IN_DECLARED_ENVELOPE`. The envelope will not be widened after observing this result.

Within a bracket, N0 bisection runs for at most 12 iterations and may stop earlier when relative bracket width is at most 0.001.

After bisection:

- C- = 0.90 times the frozen transition multiplier;
- C0 = the frozen transition multiplier;
- C+ = 1.10 times the frozen transition multiplier.

These values must be committed to a C0 result file before C1 is created or executed.

## Interpretation boundary

C0 cannot support NUM-UNC novelty. It only identifies a physical transition surface without reference to N1.

C1 can test whether N0 and N1 give different event-level inference and whether trajectory divergence grows after switching. A C0 result near the exact classification boundary does not itself count as numerical fragility.
