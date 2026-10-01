# F-MACRO-ALT18 — GFZ Griessfirn data materialization and parser result

Date: 2026-10-01

Status: `QUALIFIED_DATA_INTERFACE / PAYLOAD_MATERIALIZATION_BLOCKED_IN_CURRENT_TOOL_PATH`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Purpose

Move ALT17 from article-level evidence to the actual GFZ data product:

```text
10.5880/GFZ.4.4.2024.001
```

without adding or tuning RFM physics.

## Official dataset structure recovered

The GFZ data description confirms that the published archive contains tab-delimited text files.

For the calcareous Griessfirn forefield the soil-moisture files are:

```text
2024-001_Hartmann-et-al_Soilmoisture_C_160
2024-001_Hartmann-et-al_Soilmoisture_C_4900
2024-001_Hartmann-et-al_Soilmoisture_C_13500
```

Each file contains three plots identified by position:

```text
left
middle
right
```

For each plot:

```text
TS_XXX
SMT10_1_XXX
SMT30_XXX
SMT50_XXX
SMT10_2_XXX
SMT10_3_XXX
SMT10_4_XXX
```

where the core vertical sensor profile is:

```text
10 cm
30 cm
50 cm
```

and four 10-cm sensors sample spatial variation across the plot.

Timestamps use:

```text
DD.MM.YYYY hh:mm
UTC+2
```

and soil moisture is volumetric:

```text
cm3/cm3
```

## Trinary dye data

The calcareous dye files follow:

```text
2024-001_Hartmann-et-al_TrinaryImage_C_XYZ_XXX_YYmmh_Z
```

where:

- XYZ = moraine age 160, 4900, 13500 y;
- XXX = left/middle/right;
- YY = irrigation intensity 20, 40, 60 mm/h;
- Z = profile number.

Each file is a 1-mm pixel matrix:

```text
1 = stones/grass
2 = unstained soil
3 = blue-stained soil
```

This is sufficient to calculate without subjective image classification:

- stained fraction versus depth;
- maximum stained depth;
- connected/isolated stained regions if desired;
- path-width distributions;
- intensity response using unchanged structural geometry.

## Experimental structure confirmed

The official data description confirms:

- three plots per moraine;
- soil-moisture sensors at 10, 30 and 50 cm in a vertical profile;
- three consecutive irrigation days with different intensities for the deuterium experiment;
- for the calcareous dye experiment, 40 mm total water applied at 20, 40 and 60 mm/h;
- five excavated vertical profiles per dye subplot at about 10-cm horizontal increments.

## Persisted parser

`tools/research/macropore_alt18_gfz_parser.py`

The parser is standard-library only and accepts the native GFZ tab-delimited files.

For soil moisture it:

- discovers plot IDs from column names;
- parses UTC+2 timestamps;
- exposes the 10/30/50-cm profile and spatial 10-cm sensors.

For trinary dye files it computes:

- stained fraction versus pixel-depth;
- total stained/soil pixels by depth;
- maximum stained depth.

No RFM parameter is fitted.

## Materialization attempt

The public GFZ metadata, data description and exact file names are accessible in the present environment.

Direct retrieval of the individual data text files through the inferred GFZ download path is not accessible through the current web/download tool route.

The current workunit therefore stops short of inventing or transcribing the actual time series.

This is a **data transport blocker**, not a scientific blocker.

## Important analysis requirement once payload is available

The three consecutive deuterium irrigations mean that soil-moisture responses must be paired with the exact irrigation-day/intensity chronology.

Do not infer intensity solely from response magnitude.

Required event table:

```text
moraine age
plot
irrigation day/start
irrigation intensity
initial theta10/theta30/theta50
spatial theta10 mean/CV
onset10/onset30/onset50
peak response
lag 10->30
lag 30->50
non-sequential response flag
```

The dye data can be analyzed independently because irrigation intensity is encoded in the filename.

## Direct RFM observables

Once materialized, no full SWAP calibration is required for the first discrimination test.

### Soil moisture

Compare intensity/state ordering of:

```text
arrival/onset at 10, 30, 50 cm
deep-before-shallow / non-sequential response
lag times
response magnitude
```

### Dye

Compare:

```text
maximum stained depth
stained fraction versus depth
number/width/connectivity of stained paths
```

across 20, 40 and 60 mm/h while keeping RFM structural geometry fixed per moraine.

## Falsification rule carried forward

For each moraine/plot structural class:

```text
same geometry parameters across 20/40/60 mm/h
```

is mandatory.

If one continuous connectivity distribution cannot reproduce the observed intensity ordering without re-fitting geometry, ALT05/F5 fails.

## Decision

```text
GFZ_DATA_SCHEMA = CLOSED
GFZ_PARSER = PERSISTED
DYE_INTENSITY_MAPPING = CLOSED_FROM_FILENAME CONTRACT
SOIL_MOISTURE_DEPTH_MAPPING = CLOSED
SOIL_MOISTURE_EVENT_INTENSITY_CHRONOLOGY = REQUIRES PAYLOAD/COMPANION METADATA
RAW_PAYLOAD_MATERIALIZATION = BLOCKED_IN CURRENT TOOL ROUTE
```

## Next authorized action

Try alternate retrieval/materialization routes for the GFZ archive or accept a user-provided/local copy if already available.

If the raw GFZ archive remains inaccessible, use the published HESS tables/figures as the bounded ALT18 external evidence and move to a separate accessible dataset rather than changing RFM equations.
