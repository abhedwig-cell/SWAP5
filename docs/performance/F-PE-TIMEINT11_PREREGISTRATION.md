# F-PE-TIMEINT11 preregistration — TR-BDF2 / ESDIRK cost feasibility

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@2bf6c717647dc3fce685d5b46af5a8d859d2255a`

Parent authority:

- TIMEINT05: variable-step fully implicit BDF2 ratio<=2 qualified;
- TIMEINT10: mixed-order embedded BE correction is conservative but unusably restrictive on blind holdout;
- TIMEINT10 closeout identifies TR-BDF2 / ESDIRK-style co-designed embedded integration as the next candidate family.

## Purpose

Before implementing a new staged Richards residual, establish whether a two-stage stiff method has a credible performance envelope at all.

This workunit starts with an optimistic deterministic-work lower bound.

It does not claim that the lower-bound composite is TR-BDF2.

## TR-BDF2 structure

Use the standard L-stable TR-BDF2 parameter:

`gamma = 2 - sqrt(2)`.

A true TR-BDF2 step consists of:

1. trapezoidal stage over `gamma*h`;
2. variable-step BDF2 stage from the trapezoidal stage to the final endpoint.

The second stage is already representable by TIMEINT05 variable-step BDF2.

The first trapezoidal stage requires a new staged residual because it averages the spatial Richards operator between accepted origin and stage endpoint.

## Optimistic work lower bound

For one outer interval `h`, execute test-only:

1. one fully implicit Backward Euler solve over `gamma*h`;
2. one fully implicit variable-step BDF2 solve over `(1-gamma)*h`, using:
   - the BE stage as the immediately previous state;
   - the outer origin as the second history state;
   - previous/current substep ratio implied by gamma.

This BE+BDF2 composite is not used for accuracy claims.

Its only purpose is to estimate the minimum nonlinear work of a two-stage architecture using existing solver machinery.

A true trapezoidal first stage is not expected to require less than one implicit solve.

## Comparator

Single fully implicit variable-step BDF2 over the same outer interval.

Use the smooth fixed-flux research envelope:

- B01 and O05;
- infiltration 2 and 4 cm/day;
- constant outer dt 0.010 and 0.005 d;
- horizon 0.04 d.

Use the same:
- fully implicit conductivity;
- BDF2 representation-aware balance floor;
- MAXIT/backtracking;
- constitutive/provider path.

## Metrics

Per trajectory:

- completed outer intervals;
- nonlinear iterations;
- backtracks;
- Jacobian builds;
- linear solves;
- deterministic work index;
- work ratio two-stage-lower-bound / single BDF2.

## Frozen cost decision

If the median lower-bound work ratio is:

- <=1.40:
  - advance exact TR-BDF2 residual implementation as a plausible general integrator candidate;
- >1.40 and <=1.70:
  - exact TR-BDF2 may advance only if there is a separately justified accuracy/stability advantage;
- >1.70:
  - reject TR-BDF2/ESDIRK as the default smooth-regime production integrator;
  - retain only as a possible transition/restart fallback candidate.

Any failure of the optimistic composite also blocks general-integrator advancement.

## Why this threshold

Variable-step BDF2 already provides second-order smooth-regime accuracy with approximately one nonlinear solve per accepted step.

A second-order two-stage method paying near 2x nonlinear work would need implausibly large systematic timestep gains in smooth regions merely to break even.

## Production boundary

No production source change.

Possible classifications:

- `TRBDF2_GENERAL_CANDIDATE_ADVANCES`;
- `TRBDF2_NEEDS_ACCURACY_JUSTIFICATION`;
- `CLOSED_TRBDF2_DEFAULT_COST_TOO_HIGH`.
