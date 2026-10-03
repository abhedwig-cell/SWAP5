# F-PE-ELASTIC72B — NOBV raw-data request specification

Date: 2026-09-30

Status: DATA_ACCESS_BLOCKER_SPECIFIED

Purpose:
obtain only the raw observational fields needed to test reversible saturated
peat skeleton specific storage identifiability.

Scientific authority:
van Asselen et al. (2025), Hydrology and Earth System Sciences 29, 1865-1894,
DOI 10.5194/hess-29-1865-2025.

The publication states that raw data are stored at Deltares and in the NOBV
database and can be made available by contacting an author or
info@nobveenweiden.nl.

## Preferred sites

Priority 1:
- Zegveld, because the published study reports a thick peat sequence and a
  relatively large saturated poroelastic contribution.

Priority 2:
- Aldeboarn;
- Assendelft.

Rouveen should be treated cautiously because the published study reports
irreversible saturated deformation in the PWIS plot.

Vlist remains useful when anchor/lithology geometry provides a clean saturated
peat-bounded interval.

## Required raw time series

For each selected parcel/extensometer:

1. timestamp;
2. displacement/elevation change for every available extensometer anchor, not
   only the approximately 0.05 m and 0.80 m anchors used in the summary paper;
3. exact anchor depth/elevation and reference-anchor identity;
4. local phreatic groundwater level at the monitoring well used for the
   extensometer comparison;
5. if available, deeper hydraulic-head/pore-pressure observations;
6. sensor quality flags, resets, recalibrations, gaps and maintenance events;
7. measurement units and sign conventions;
8. raw or documented measurement precision/resolution.

Hourly data are preferred because the publication states that extensometer
measurements were recorded hourly and discusses daily/weekly near-immediate
responses.

## Required static metadata

For every anchor-bounded interval:

- lithology / soil profile;
- peat versus clay versus sand attribution;
- layer top and bottom depth;
- organic-matter information where available;
- groundwater-regime description;
- WIS/reference parcel identity;
- drain location relative to extensometer;
- reference-anchor depth and supporting firm-substrate interpretation.

## Minimum analysis-ready geometry

At least one pair of adjacent anchors must bound a layer that:

- is peat-dominated;
- remains saturated through candidate reversible cycles;
- has known reference thickness;
- has simultaneous groundwater-head data;
- is not crossed by a major lithological transition unless that mixed interval
  is explicitly retained as mixed rather than called peat-specific.

## Desired period

Prefer the complete available high-resolution period from 2020-2023, with 2019
included where available.

Do not preselect only visually clean seasonal cycles before the data are
received.

## Requested provenance

Please retain:
- original filenames;
- data dictionary;
- site/parcel identifiers;
- instrument identifiers;
- processing level (raw, corrected, filtered, daily average, etc.);
- version/date;
- contact/source.

## Analysis boundary after receipt

Before estimating any Ss:

1. freeze file hashes and provenance;
2. inventory all anchors, sites and time coverage;
3. classify saturation eligibility without looking at resulting Ss values;
4. preregister cycle selection, detrending, lag and hysteresis thresholds;
5. preserve at least one site or time block as independent validation where
   data volume permits.

No production peat parameterization follows directly from data receipt.
