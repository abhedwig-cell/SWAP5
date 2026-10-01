# F-MACRO-ALT46 — NEON binary-PF discrimination and sigma_B identifiability

Date: 2026-10-01

Status: QUALIFIED_EMPIRICAL_DISCRIMINATION_RESULT / SIGMA_B_NOT_IDENTIFIABLE_FROM_BINARY_LABELS

## Purpose

Test whether the frozen RFM surface-activation score contains empirical preferential-flow information on the ALT45 hydraulically valid NEON subset, before attempting a sigma_B fit.

## Event score

For each valid event:

- source magnitude = NEON stormPeakIntensity converted from mm/10 min to cm/day;
- event age = elapsed time from storm start to peak, with a 5-minute lower bound corresponding to the half-width of the 10-minute precipitation interval;
- K_surface = ALT45 Rosetta/SWAP-compatible conductivity;
- S_surface = ALT12 transformed sorptivity integral;
- RFM preferential fraction = frozen distributed-infiltrability activation formula.

Observed binary PF is:

    flowTypes == nonSequentialFlow

OR any available:

    PF_velocity_metric_50X == True

This is the same bounded diagnostic class used in the earlier NEON work.

## Sample

    n = 34,355 hydraulically valid events
    observed PF = 14,274
    observed PF prevalence = 0.4155

## Discrimination

Using provisional sigma_B = 0.65:

    AUC ~ 0.6658

Observed PF frequency by RFM activation-score quintile:

    lowest quintile   ~ 0.220
    second quintile   ~ 0.318
    middle quintile   ~ 0.405
    fourth quintile   ~ 0.522
    highest quintile  ~ 0.612

This is a strong monotone empirical ordering.

Therefore:

    RFM_ACTIVATION_SCORE_CONTAINS_REAL_PF_INFORMATION = SUPPORTED

The result does not prove the absolute preferential-water fraction predicted by RFM.

## sigma_B sensitivity

AUC values:

    sigma_B = 0.30  -> ~0.6653
    sigma_B = 0.50  -> ~0.6658
    sigma_B = 0.65  -> ~0.6658
    sigma_B = 0.80  -> ~0.6658
    sigma_B = 1.00  -> ~0.6658
    sigma_B = 1.30  -> ~0.6658

Changing sigma_B materially changes the absolute RFM preferential fraction but barely changes event ranking.

This is exactly the identifiability problem that matters for ALT35.

## Scientific conclusion

Binary PF occurrence is useful for testing whether the activation score orders events sensibly.

It is NOT sufficient by itself to estimate sigma_B, because sigma_B largely rescales the activation magnitude while preserving ordering.

Any attempt to fit sigma_B directly to 0/1 PF labels would require an additional observation model linking modeled preferential fraction to PF detection probability.

That observation model would introduce nuisance parameters and was not part of the frozen ALT35 contract.

Therefore it must not be invented after looking at these results.

## Consequence for ALT35

The fixed-sigma_B transferability hypothesis remains open.

The empirical situation is now much sharper:

    activation ordering = empirically supported
    generic sigma_B=0.65 = already not justified as a universal default
    sigma_B magnitude = not identified by NEON binary occurrence alone

A quantitative preferential-flow amount, calibrated observation operator, tracer mass fraction, or comparable continuous target is required to estimate sigma_B itself.

## Decision

    NEON_ACTIVATION_DISCRIMINATION = PASS
    BINARY_PF_LABEL_INFORMATION = USEFUL_FOR_RANKING
    SIGMA_B_FROM_BINARY_LABELS = NON_IDENTIFIABLE
    POST_HOC_BINARY_OBSERVATION_MODEL = NOT AUTHORIZED
    ALT35_FIXED_SIGMA_TRANSFERABILITY = REMAINS_OPEN
