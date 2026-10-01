# F-MACRO-ALT35 — fixed-sigma_B transferability empirical gate

Date: 2026-10-01

Status: EMPIRICAL_TRANSFERABILITY_BLOCKED / TEST_PREREGISTERED / FIXED_SIGMA_B_NOT_FALSIFIED

Baseline: integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b

## Purpose

Test the remaining central activation hypothesis:

    one sigma_B per structural soil/profile

must transfer across events without event-specific retuning.

## Why ALT35 is now decisive

ALT34 showed that the complete RFM routing chain is conservative and executable against a retained SWAP5 hydraulic fixture, but the provisional sigma_B=0.65 produced very high absolute preferential fractions.

That makes sigma_B transferability the dominant unresolved empirical question. Routing and mass accounting are no longer the limiting issues.

## External event database identified

The 2025 NEON Soil Preferential Flow Database is directly suitable for this test. Its published schema includes, per precipitation event:

    stormStartTime / stormEndTime
    stormSum
    stormPeakIntensity
    stormDuration
    smBeforePrecip_50X
    soil-moisture onset/peak response fields
    flowTypes
    flowPosition
    velocity_computed_50X
    multiple PF velocity/Ksat labels

plus soil texture, porosity, root-density and site properties.

This is enough in principle to form within-profile calibration and held-out event sets.

## Payload blocker

The current HydroShare resource is published and about 1 GB in size, but the event file payload is externally linked and is not machine-materializable through the current execution path. The resource page/metadata is searchable, while direct resource opening/file download returns a gateway failure in this environment.

Therefore no event rows were invented, reconstructed from aggregate figures, or pseudo-calibrated.

## Published empirical pressure

The peer-reviewed NEON analysis reports that preferential-flow occurrence is more likely with increased peak rainfall intensity and also depends on antecedent soil moisture. Importantly, coefficient of variation of antecedent soil moisture is one of the major predictors, and low moisture variability is associated with higher PF probability.

This matters for RFM because fixed sigma_B currently represents subgrid surface-intake heterogeneity while the hydraulic binding uses an accepted top-state mean.

If event-level antecedent moisture variability changes independently of that mean state, fixed sigma_B may be structurally insufficient.

However, the aggregate random-forest result is not a valid direct falsification of fixed sigma_B. It mixes sites, soil properties and climate, and does not provide the within-profile held-out event likelihood required by the preregistered test.

## Preregistered transferability test

Calibration unit:

    one NEON site/profile

Calibration rule:

    fit one sigma_B on a calibration subset
    derive hydraulic state quantities from event antecedent state
    hold sigma_B fixed afterward

Held-out strata must include:

    weak versus intense source events
    short versus long events
    low versus high antecedent mean water content
    low versus high antecedent spatial moisture variability

Primary targets:

    PF occurrence / no occurrence
    response-depth ordering
    deep response / velocity-threshold PF label

No event-specific geometry or sigma_B adjustment is permitted.

## Rejection rules

Reject fixed sigma_B for the profile if, after profile-level calibration:

1. residual error changes systematically with rainfall intensity;
2. residual error changes systematically with event duration;
3. residual error changes systematically with antecedent state after K/S state dependence is accounted for;
4. antecedent spatial-moisture variability retains a systematic effect that cannot be represented by the fixed-sigma_B/top-state model.

Rule 4 is particularly important because the published NEON result already identifies moisture variability as an important predictor.

## Current scientific verdict

    sigma_B=0.65 as generic default = rejected by ALT34
    one fixed sigma_B per structural profile = not yet falsified
    event-specific sigma_B = forbidden
    state-dependent sigma_B = not authorized yet
    empirical event-payload access = real blocker

## Research-line consequence

The correct next move is not to add another activation parameter.

The RFM physical architecture remains the leading reduced hypothesis, but empirical admission of its activation law is blocked until event-level data can be materialized.

This is an explicit scientific blocker, not a software blocker and not a failure of the routing architecture.

## Exit condition

Resume this line only when one of the following becomes available:

- the NEON PF event CSV payload;
- the GFZ Griessfirn raw event/dye payload;
- another public within-profile event dataset containing forcing, antecedent state and preferential-flow response.

At that point execute the preregistered held-out test without altering the frozen RFM parameter contract first.
