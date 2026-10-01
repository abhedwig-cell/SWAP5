# F-MACRO-RFM-RC1 — Research Candidate 1 closeout

Date: 2026-10-01

Status: QUALIFIED_RESEARCH_CANDIDATE / EMPIRICAL_ADMISSION_BLOCKED

Branch: research/f-macro-alt01-memory-falsification

## Scope

This closeout freezes the broad alternative macropore/preferential-flow research line through F-MACRO-ALT35.

RFM-RC1 is a reduced alternative physical hypothesis for preferential flow in SWAP5. It is not the production migration of the existing SWAP macropore module and does not replace the canonical reference route.

## Frozen physical architecture

Surface boundary owner:

    rainfall / irrigation
      -> ponding/runoff resolution
      -> effective infiltrating source

Unponded activation:

    accepted top hydraulic state
      -> K_surface
      -> S_surface
      -> b50(tau_surface) = K_surface + S_surface/(2 sqrt(tau_surface))
      -> B ~ LogNormal(log b50, sigma_B)
      -> q_matrix = E[min(R_eff,B)]
      -> q_pref = R_eff - q_matrix

Connectivity:

    C_struct(z) = 1 - x^p
    x = (z-Z_AH)/(Z_IC-Z_AH)

Event-active IC connectivity:

    fixed structural endpoint population
      + activation-weighted quantile recruitment

Fast-domain functional split:

    MB = persistent continuous/deep pathways
    IC = terminating recruited pathways

Wall exchange:

    hydraulic-derived Philip/sorptivity exchange
    plus wet-state Darcy exchange
    with optional chi_wall correction only where evidence requires it

## Frozen parameter contract

RFM-minimal free high-level parameters:

    sigma_B
    f_MB
    p

RFM-wall-corrected:

    sigma_B
    f_MB
    p
    chi_wall

Derived/observed rather than calibrated by default:

    Z_AH
    Z_IC
    K_surface
    S_surface
    ell_ex
    surface ponding/runoff state

Removed from the leading reduced parameterisation:

    event-specific sigma_B
    free R_AH
    separate shape-a and shape-b
    empirical SORPMAX/SORPALFA route
    free ShapeFacMp
    explicit multiple IC subdomain identities

## Frozen state contract

Persistent information roles:

    fast-domain water storage
    S_wall,event
    tau_wall,event
    tau_surface

Derived/scratch roles:

    active connectivity
    dynamic/total macropore volume where needed
    active bottom index
    wet-wall/contact fraction
    rate/Jacobian intermediates
    candidate mass receipts

Rejected trials must not publish or retain candidate RFM state or receipts.

## Qualified results

1. Strictly memoryless preservation of Philip wall absorption was falsified.
2. Two-value wall event memory S_event + age_event is analytically sufficient for the retained Philip continuation semantics.
3. Continuous MB/IC connectivity is feasible and conservative.
4. Dynamic activation derived from K_surface + S_surface/(2 sqrt(tau)) is source-responsive without a free characteristic time.
5. Surface sorptivity is derivable from the constitutive provider through the transformed Parlange integral.
6. Activation-weighted connectivity resolves the fixed-active-depth limitation without event-specific geometry.
7. Water and conservative-tracer routing close at floating-point scale in standalone and retained-fixture composition tests.
8. R_AH is locally non-identifiable with the earlier shape-a role and is removed from the leading candidate.
9. One-shape connectivity C(z)=1-x^p retains the required qualitative depth-response regimes with good local conditioning.
10. Wall-exchange input burden reduces to derived ell_ex plus optional chi_wall; ell_ex is structurally derivable from macropore/ped geometry.
11. Source-level research adapters now consume accepted SWAP5 hydraulic views and constitutive providers without duplicating production hydraulic equations.
12. Retained SWAP5 default-MvG fixture composition is end-to-end conservative.

## Explicitly falsified/rejected routes

    strict memoryless wall absorption
    one cumulative scalar as complete Philip history
    arbitrary free activation characteristic time
    event-specific geometry refit
    fixed active depth distribution independent of activation
    categorical dye flow type as one-to-one preferential water flux proxy
    free R_AH in the leading reduced geometry
    generic sigma_B = 0.65 default
    ell_ex as a default unconstrained calibration parameter

## Empirical admission blocker

The remaining decisive hypothesis is:

    one sigma_B per structural profile transfers across held-out events

without event-specific retuning.

The required NEON/GFZ-style event payloads have been identified but are not machine-materializable in the current execution path. The ALT35 test is preregistered.

Therefore:

    fixed sigma_B per profile = NOT FALSIFIED
    empirical admission = BLOCKED
    state-dependent sigma_B = NOT AUTHORIZED

## Engineering status

RFM-RC1 is ready for sidecar/shadow research execution because:

- the parameter/state contract is frozen;
- the source-level hydraulic adapter exists;
- provider-bound S_surface and K_surface are available;
- the endpoint router is conservative;
- no production ownership mutation is required for diagnostics.

## Production status

NOT PRODUCTION ADMITTED.

The existing production macropore migration/audit remains independently governed by PPA-WU05-A and successors. RFM-RC1 must remain opt-in research/shadow functionality until empirical admission is earned.

## Resume conditions

Resume physical-model development only if:

1. event-level empirical payload becomes available and ALT35 is executed; or
2. shadow execution reveals a reproducible architecture/interface defect; or
3. held-out empirical evidence falsifies one of the frozen RFM-RC1 assumptions.

Do not resume by adding new free parameters merely to improve retained-fixture visual plausibility.
