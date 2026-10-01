# F-MACRO-ALT47 closeout — quantitative preferential-flow observable search

Date: 2026-10-01

Status: CLOSED_WITH_QUANTITATIVE_SIGMA_B_OBSERVABLE_BLOCKER / p_AND_fMB_PATHS_IDENTIFIED

## Closed question

Can the currently available public datasets provide a continuous observation that identifies the absolute RFM surface-activation scale sigma_B without introducing a new post-hoc observation model?

Answer:

    not yet.

## What is available

GFZ Hartmann 2024 provides controlled irrigation, multi-depth soil moisture, delta2H profiles and trinary dye images.

HILLSCAPE Maier 2021 provides controlled sprinkling, quantitative overland and shallow subsurface flow, event-water fractions and tracer-mixing information.

Weiherbach/Spechtacker-site33 provides published quantitative vertical bromide mass profiles together with measured macropore structure.

NEON PF v1.1 provides large-sample event occurrence/ranking evidence.

## What each source can identify under the frozen ALT47 observation contract

    sigma_B:
        requires direct preferential-entry fraction or independently calibrated conservative-mass equivalent;
        no currently materialized/open candidate meets this cleanly.

    f_MB:
        HILLSCAPE external/deep receipts are promising;
        bromide deep tracer mass is promising;
        GFZ isotope profile is conditional on mass/flow separation.

    p:
        GFZ trinary dye depth shape is admissible;
        bromide normalized depth mass profile is admissible.

## Explicitly rejected shortcuts

- treating dye stained area as proportional preferential-water volume;
- treating PFF as preferential-water fraction;
- fitting sigma_B to binary PF occurrence through a post-hoc logistic/threshold model;
- extracting quantitative bromide values from published figures;
- deconvolving three sequential GFZ isotope irrigation days with an unpreregistered transport model.

## Materialization attempt

The GFZ Data Services metadata pages expose the datasets and document public ZIP downloads, but the execution environment does not expose the underlying data ZIP URLs as machine-resolvable download links.

Therefore immediate GFZ/HILLSCAPE execution stops on a transport/tooling blocker, not a scientific one.

## Resume conditions

Resume immediately if any of the following are materialized locally:

1. GFZ 2024 tracer/dye dataset DOI 10.5880/GFZ.4.4.2024.001;
2. HILLSCAPE dataset DOI 10.5880/fidgeo.2021.011;
3. original Weiherbach Spechtacker/site33 bromide data;
4. a dataset with direct matrix-versus-preferential infiltration partition.

When data are available, execute the already frozen observation operator before any RFM retuning.

## Final ALT47 status

    quantitative observable search = CLOSED
    observation operators = PREREGISTERED
    model physics = FROZEN
    sigma_B absolute calibration = BLOCKED
    p empirical qualification = READY_ON_DATA
    f_MB empirical qualification = READY_ON_DATA
