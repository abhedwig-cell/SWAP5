# F-MACRO-ALT45 — NEON antecedent-state to Rosetta/SWAP hydraulic binding

Date: 2026-10-01

Status: QUALIFIED_PARTIAL_EMPIRICAL_HYDRAULIC_BINDING / COVERAGE_LIMITS_EXPLICIT

## Purpose

Map NEON event antecedent soil moisture to a pressure-head/conductivity/sorptivity state using the ALT44 Rosetta v3 hydraulic sensitivity layer.

## Dataset exclusions

The HydroShare resource itself recommends against using:

    BONA, DEJU, HEAL, TOOL, BARR

and excludes KONA from the paper analysis because of site ambiguity.

ALT45 excludes these six sites.

Remaining:

    40 sites
    200 profile files

## Binding rule

For each event:

1. select the shallowest sensor with a finite `smBeforePrecip_50X`;
2. use that sensor depth;
3. locate the corresponding Rosetta site horizon using `hzndept <= depth <= hzndepb`;
4. invert the Rosetta van Genuchten retention curve to pressure head;
5. use Rosetta Ksat and L in the SWAP-compatible MvG conductivity form;
6. evaluate surface sorptivity with the frozen ALT12 transformed integral.

No RFM parameter is fitted in this step.

## Coverage

Primary PF database:

    67,385 events total

After source-recommended site exclusions:

    47,618 events have a finite antecedent state at at least one sensor
    47,611 map to a Rosetta site horizon
    34,355 have theta_r < observed theta < theta_s and therefore a finite inverse head

Hydraulic-state coverage therefore spans 198 of the 200 remaining profiles.

## Important limitation

A substantial number of events cannot be inverted:

    observed theta <= Rosetta theta_r : 12,731 events
    observed theta >= Rosetta theta_s :    499 events

This is direct evidence that site-horizon Rosetta PTF parameters are not a neutral exact representation of every sensor/profile.

Therefore ALT45 must not silently clip those observations into the retention domain.

They are excluded from the hydraulic-screen subset.

## Valid-state distribution

For the 34,355 valid events, inverted pressure heads span an extremely broad dry-to-wet range.

Representative quantiles:

    median h   ~ -825 cm
    75th pct   ~ -198 cm
    90th pct   ~  -55 cm
    99th pct   ~  -15 cm

The extreme dry tail confirms that hydraulic uncertainty is potentially important for weak-event activation.

## Interpretation

The ALT43 blocker has changed:

Before ALT44/45:

    profile constitutive hydraulics unavailable

After ALT44/45:

    a source-consistent Rosetta hydraulic sensitivity binding exists for a large subset

but:

    exact profile hydraulic authority remains unavailable

This is sufficient for falsification/sensitivity work, not for claiming calibrated field hydraulic parameters.

## Decision

    EVENT_LEVEL_HYDRAULIC_BINDING = AVAILABLE_FOR_34,355_EVENTS
    198_OF_200_PROFILES_HAVE_VALID_EVENTS
    OUT_OF_RETENTION_DOMAIN_EVENTS = EXCLUDED_NOT_CLIPPED
    HYDRAULIC_UNCERTAINTY = MUST_REMAIN_EXPLICIT
