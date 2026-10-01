# PPA-WU05-A12 result — RFM hydraulic-view and sorptivity binding

Date: 2026-10-01

Status: QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE

Baseline:

    integration/f-ci-canonical@03708d387f452e82044cffbff681da8252d3e717

Qualified postimage:

    facfca66e0656e622c2677a0392aa44d9bedb29d

Qualification run:

    36860909511 — SUCCESS

Focused gate output:

    PPA_WU05A12_RFM_HYDRAULIC_BINDING=PASS

## Qualified composition

A12 binds an explicit process hydraulic view and constitutive provider to the
canonically admitted A11 activation service:

    process hydraulic view
      -> top-node K_surface
      -> transformed-integral S_surface
      -> explicit sigma_B/source/event-age inputs
      -> A11 unponded activation partition.

No FMR source ownership is changed by this workunit.

## Sorptivity oracle

The independent synthetic constitutive fixture is:

    theta(h) = 0.4 + 0.002 h
    K(h) = 1 cm/day
    h_initial = -100 cm
    theta_initial = 0.2

The transformed integral is exactly linear:

    integral = 30
    S = sqrt(30) = 5.477225575051661

The focused gate reproduces that value and then composes it through A11.

For:

    sigma_B = 0.65
    source = 8 cm/day
    event age = 0.25 day

the qualification oracle reproduces:

    b50 = 6.477225575051661
    matrix = 5.961748798503473
    preferential = 2.038251201496527
    fraction = 0.25478140018706585

within 1e-12 tolerance.

## Fail-closed behavior

Qualified:

- invalid/nonpositive quadrature panel count -> binding unavailable;
- unavailable/invalid point conductivity -> binding unavailable;
- positive ponding is carried into A11 and returns
  SURFACE_BOUNDARY_REQUIRED;
- sigma_B, source and event age remain explicit caller-owned inputs.

## First-run negative finding

Qualification run 36860761059 failed before test execution because the synthetic
test provider was initially declared inside a program with internal procedures,
which gfortran does not accept as type-bound overrides.

The production modules compiled before that test-harness failure.

The test provider was moved to a test-only module with no production-source
change. The exact repaired postimage was then qualified by run 36860909511.

## Architecture boundary

A12 admits derivation/composition only.

It does not:

- choose sigma_B;
- own event age;
- modify committed/candidate state;
- take over A8/A9/A10 top-input ownership;
- route preferential water;
- introduce f_MB, p or chi_wall;
- add a ponded activation branch.

## Lifecycle

    implemented -> persisted -> tested -> qualified

Canonical admission is not claimed by this result.
