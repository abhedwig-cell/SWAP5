# F-MACRO-RFM-RC1 — empirical addendum after NEON materialization

Date: 2026-10-01

Status: EMPIRICAL_SCREEN_COMPLETED / ACTIVATION_ORDERING_SUPPORTED / SIGMA_B_MAGNITUDE_NOT_IDENTIFIED

Research branch: research/f-macro-alt01-memory-falsification

## What changed since RC1 closeout

The previously unavailable NEON preferential-flow payload has now been materialized from HydroShare resource 847b15cd15524b78acd58a2a8be242c1.

The payload contains 230 profile files and 67,385 precipitation events.

Therefore the earlier event-payload blocker is closed.

## Paired natural-event evidence

ALT43 executed the preregistered style of paired-event screening.

Duration:

    174 independent profile-local short/long pairs
    PF short ~11.5%
    PF long  ~10.3%
    exact paired p ~0.86

Weak to intermediate intensity:

    55 independent profile-local pairs
    PF weak         ~12.7%
    PF intermediate ~16.4%
    exact paired p  ~0.77

The simple natural-storm duration signature is therefore not supported by these aggregated event descriptors.

The intensity direction is weakly consistent but not decisive.

These outcomes do not directly falsify RFM because the natural-event table supplies peak intensity rather than the complete effective source time series, and binary PF labels are not preferential-water fractions.

## Hydraulic authority added

ALT44 reproduced the dataset authors' Rosetta3 Ksat horizon values with:

    median relative error ~8.2e-09
    maximum relative error ~6.7e-08

using Rosetta v3 texture-only model code 2 and geometric/log ensemble means.

This authorizes a bounded Rosetta VG-Mualem hydraulic sensitivity layer.

ALT45 then bound event antecedent theta to that layer.

Hydraulically valid subset:

    34,355 events
    198 profiles

A substantial out-of-domain fraction remains and is excluded rather than clipped.

## Strongest empirical result

ALT46 shows that the frozen RFM activation score contains substantial empirical preferential-flow ordering information.

Observed PF frequency increases approximately:

    22% -> 32% -> 40% -> 52% -> 61%

from the lowest to highest activation-score quintile.

AUC:

    ~0.666

This result is stable over sigma_B from about 0.3 through 1.3.

## Identifiability verdict

The same stability is also the key negative result.

Binary PF occurrence changes little in ranking when sigma_B changes even though the absolute modeled preferential fraction changes materially.

Therefore:

    sigma_B is not identifiable from NEON binary PF labels alone.

A post-hoc logistic or threshold observation model could force a numeric sigma_B estimate, but that would introduce extra nuisance parameters after seeing the data and is not authorized by the frozen ALT35 contract.

## Current blocker

The remaining blocker is no longer data access or basic hydraulic parameters.

It is the lack of a quantitative observation that maps directly enough to preferential water amount, such as:

- preferential tracer mass fraction;
- independently estimated preferential water flux/fraction;
- controlled rainfall-simulator water partition;
- or a separately preregistered observation operator with independent calibration.

## RFM-RC1 status after empirical screening

    reduced architecture = retained
    source-level SWAP5 integration = retained
    end-to-end conservation = retained
    activation event ordering = empirically supported
    generic sigma_B=0.65 default = not supported
    profile-level fixed sigma_B = still not falsified
    sigma_B magnitude from binary NEON PF = non-identifiable
    production admission = blocked

## Resume condition

Do not alter RFM physics.

Resume sigma_B calibration only when a quantitative preferential-flow observable or independently justified observation operator is available.

NEON may still be used for ranking, stratification, held-out event ordering and hydraulic/state sensitivity tests.
