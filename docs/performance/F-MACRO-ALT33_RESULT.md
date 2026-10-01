# F-MACRO-ALT33 — retained SWAP5 hydraulic fixture activation and quadrature cost

Date: 2026-10-01

Status: QUALIFIED_RESEARCH_NUMERICAL_SCREEN / REAL_SWAPS_FIXTURE_PARAMETERS_CONSUMED

Baseline: integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b

## Purpose

Execute the frozen RFM surface-hydraulic chain against an existing SWAP5 default-MvG runtime fixture rather than another invented hydraulic parameter set.

## Fixture authority

The source is tests/fkt/test_fkt22_fmr_serialized_trajectory_runtime.f90.

That production/runtime test initializes a homogeneous default-MvG profile with:

    theta_r = 0.032
    theta_s = 0.423
    Ksat    = 4.75 cm/day
    alpha   = 0.0135 1/cm
    n       = 1.455
    lambda  = 0.365

and an accepted equilibrium fixture pressure head:

    h = -75 cm

ALT33 uses exactly that retained parameter/state anchor.

## Surface hydraulics at h=-75 cm

The numerical provider mirror gives approximately:

    theta_i   = 0.3459
    K_surface = 0.16264 cm/day
    S_surface = 2.9255

using a high-resolution midpoint evaluation of the ALT12 transformed Parlange integral.

These values are materially different from the earlier generic ALT12 example and therefore demonstrate that the RFM chain is now responding to an actual retained SWAP5 constitutive fixture.

## Quadrature convergence

For h=-75 cm:

    panels   S_surface
       8     2.87729
      16     2.90731
      32     2.91871
      64     2.92300
     128     2.92460
     256     2.92520
     512     2.92542
    1024     2.92550

Relative to 1024 panels:

    32 panels  ~0.23% low
    64 panels  ~0.086% low
    128 panels ~0.031% low

Therefore 64-128 panels are already a defensible direct research-oracle range for this state.

Python mirror timing is only a diagnostic of algorithmic scaling and is not a Fortran performance claim. The expected cost is linear in panel count.

## Activation response

At event age 0.25 day and sigma_B=0.65, using 128-panel S_surface:

    source   preferential fraction
       1        ~0.009
       2        ~0.073
       4        ~0.273
       8        ~0.551
      15        ~0.748
      30        ~0.873
      60        ~0.936

The response is smooth, bounded and strongly intensity-sensitive on this retained SWAP5 hydraulic state.

## Important interpretation

This is not empirical validation of preferential-flow amounts.

It establishes a more limited but necessary result:

    a real SWAP5 constitutive fixture
      -> realistic K_surface
      -> provider-compatible S_surface
      -> well-behaved RFM activation

without free b50, free characteristic time or external hydraulic surrogate.

## Performance implication

The direct quadrature oracle is unlikely to be intrinsically prohibitive. More importantly, S_surface depends only on accepted top hydraulic state and constitutive parameters; it need not be recomputed blindly for every inner Newton evaluation.

Potential later accelerations, only if profiling justifies them:

- 64-panel direct quadrature;
- adaptive quadrature;
- state-local cache keyed by accepted top state;
- joint constitutive lookup consistent with F-AHL work.

No optimization is admitted in ALT33.

## Decision

RETAINED_SWAPS_FIXTURE_HYDRAULIC_CHAIN = PASS
DIRECT_SORPTIVITY_QUADRATURE_CONVERGENCE = PASS
64_TO_128_PANEL_RESEARCH_ORACLE = SUPPORTED
ACTIVATION_RESPONSE = BOUNDED_MONOTONE
EMPIRICAL_VALIDATION = STILL OPEN

## Next

ALT34 should compose this retained hydraulic fixture with the ALT23 activation-weighted endpoint router. The first target is a complete research-only transaction:

    SWAP5 accepted top state
      -> provider-derived K/S
      -> RFM activation
      -> MB/IC partition
      -> one-shape endpoint recruitment
      -> conservative water/tracer receipts.

That will be the first full end-to-end RFM column-routing experiment anchored in an existing SWAP5 hydraulic fixture.
