# F-PE-ELASTIC03A — physical class hypothesis before material holdout

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_MATERIAL_HOLDOUT_RESULTS

## Premise

Specific elastic storage is a material-mechanical property. It shall not be optimized directly for solver speed.

## Frozen qualitative hypothesis

For a first physically defensible hierarchy:

1. mineral soils and organic/peat soils must not be assigned one universal ELAS solely from MvG parameters;
2. organic-rich/peat classes are expected to require a larger elastic-storage prior than relatively stiff mineral classes because their porous matrix is more compressible;
3. topsoil/subsoil distinction may matter because structure and bulk density differ;
4. within mineral soils, texture, bulk density and organic matter are candidate predictors of matrix compressibility;
5. `ELAS/C_native` remains only a numerical-risk diagnostic, not the physical parameter generator.

## Pim baseline

`ELAS = 1e-6 cm^-1` is retained as the nominated mineral-soil reference magnitude to be tested, not as a universal default.

No larger organic-soil value is selected yet because no Dutch mechanical-data authority has been acquired.

## Frozen holdout boundary

The 12 Staringreeks material holdouts remain closed:
B03, B06, B09, B15, B18, O01, O04, O07, O10, O13, O16, O18.

No dynamic holdout result may be inspected until a quantitative candidate assignment rule is frozen from independent physical evidence.

## Required next evidence

Search for:
- Dutch/Staringreeks/BIS sample bulk density and composition metadata;
- soil elastic or recompression modulus/compressibility data;
- hydrogeological specific-storage values by sediment/soil class;
- a defensible transformation from mechanical compressibility to SWAP ELAS units.

If those data are unavailable, the scientifically honest production design is a typed per-layer ELAS input with an explicit externally supplied value, not an invented pedotransfer function.
