# PPA-WU05-A12 preregistration — RFM hydraulic-view and sorptivity binding

Date: 2026-10-01

Status: PREREGISTERED_IMPLEMENTATION_IN_PROGRESS

Baseline:

    integration/f-ci-canonical@03708d387f452e82044cffbff681da8252d3e717

Prerequisite:

    PPA-WU05-A11 CLOSED_CANONICAL_ADMITTED

## Purpose

Promote the already exercised research adapter that derives the A11 activation
inputs from an accepted process hydraulic view and a constitutive provider.

A12 does not change FMR source ownership.

## Candidate composition

    process_hydraulic_view_t
      -> top-node pressure head / water content / ponding
      -> constitutive point K_surface
      -> transformed-integral surface sorptivity S_surface
      -> canonically admitted A11 activation service

The caller still owns:

    sigma_B
    source rate
    event age

## Sorptivity operator

A12 uses the frozen transformed integral already exercised in the RFM research
line:

    S = sqrt( integral[h_initial..0]
              (theta_s + theta(h) - 2 theta_initial) K(h) dh )

with nonnegative integrand clipping and explicit midpoint quadrature.

The number of quadrature panels is explicit input. No hidden accuracy setting is
introduced.

## Hard boundaries

A12 SHALL NOT:

- choose or default sigma_B;
- own event-age lifecycle;
- modify accepted/candidate physical state;
- change A8/A9/A10 source partition;
- route preferential water;
- add f_MB, p or chi_wall;
- execute a ponded RFM branch.

Positive ponding is passed to A11 and returns SURFACE_BOUNDARY_REQUIRED.

## Qualification oracle

Use an independent synthetic constitutive provider:

    theta(h) = 0.4 + 0.002 h
    K(h) = 1 cm/day
    h_initial = -100 cm
    theta_initial = 0.2

Then:

    integral = 30
    S = sqrt(30) = 5.477225575051661

With:

    sigma_B = 0.65
    R = 8 cm/day
    tau = 0.25 day

expected A11 composition:

    b50 = 6.477225575051661
    matrix = 5.961748798503473
    preferential = 2.038251201496527
    fraction = 0.25478140018706585

Because the integrand is linear in h, midpoint quadrature reproduces the
integral exactly apart from floating-point arithmetic for any positive panel
count.

## Exit criteria

One of:

    QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE_RFM_HYDRAULIC_BINDING
    SORPTIVITY_ORACLE_FALSIFIED
    CONSTITUTIVE_BINDING_FALSIFIED
    A11_COMPOSITION_FALSIFIED
    TRUE_BLOCKER
