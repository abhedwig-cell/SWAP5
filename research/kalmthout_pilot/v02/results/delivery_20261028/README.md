# Kalmthoutseheide SWAP-WOFOST variable files

Delivery revision: 28 October 2026. This revises the delivery layout of the preserved SWAP 4.3.1/WOFOST V02 results, not the model, forcing, parameters or scientific values. There are exactly four scientific NetCDF products. Each contains all 639 reporting days from 1 January 2025 through 1 October 2026 inclusive. The original annual multivariable research files remain preserved.

| File stem after `Kalmthoutseheide_SWAP_WOFOST_` | Main variable | Unit | Dimensions | Time support |
| --- | --- | --- | --- | --- |
| `GPP_20250101_20261001.nc` | GPP | umol m-2 s-1, substance CO2 | time, y, x | Full UTC-day mean, positive uptake |
| `soil_moisture_20250101_20261001.nc` | soil_moisture | kg m-3 | time, depth, y, x | End-of-day state |
| `ET_20250101_20261001.nc` | ET | mm d-1 | time, y, x | Full UTC-day mean rate, numerically equal to the daily total in mm |
| `soil_temperature_20250101_20261001.nc` | soil_temperature | degree_Celsius | time, depth, y, x | End-of-day state |

## Grid, depths and time

All 4,096 cells occupy their original 64 by 64, 250 m grid in EPSG:32631 (WGS 84 / UTM zone 31N). `x` and `y` are ascending projected centre coordinates in metres; bounds describe cell edges. The domain edges are 592980 to 608980 m east and 5683020 to 5699020 m north. Reindexing uses the original row/column assignments, with no resampling, interpolation, rotation or new geographic mask. Independent one-dimensional soil columns remain the spatial representation. Static class, crop and input-quality information remains available as ancillary metadata.

The five actual compartment centres are -10.5, -22.5, -42.5, -82.5 and -162.5 cm relative to the ground surface, with `depth.positive=up`. They have not been interpolated to the requested -10, -20, -40, -80 and -160 cm; `requested_depth` records those requests. Neither soil field is a vertical average. Soil temperature is not land-surface temperature; moisture is water mass per bulk soil volume, not kg/kg or a profile water stock.

**Read `simulation_date` as the reporting-day label.** The original time convention is preserved: `time` is at the end of the UTC day, and `time_bounds` covers the preceding day. The record labelled 2025-01-01 therefore has bounds 2025-01-01 00:00 through 2025-01-02 00:00 UTC and `time=2025-01-02 00:00 UTC`. The last reporting day is 2026-10-01; its exclusive interval end and state time are 2026-10-02 00:00 UTC. All four files use the same normalised time units, days since 2025-01-01, and proleptic Gregorian calendar. An ingestion system that labels by day start must map the reporting label or lower bound explicitly. Do not shift physical end-of-day states by silently reinterpreting their observation time.

## Definitions and missing values

ET is the previously agreed `10*(TACT+EACT+EIC)`. Pond evaporation is excluded. The native interception term includes recognised canopy-calendar accounting events; `canopy_reset_flag` remains in the ET file. This reorganisation does not repair or hide those native events.

GPP retains the source-verified crop-specific carbon conversion and native management and stress reductions. It is available for 802 grass and 503 maize-proxy cells, 1,305 cells or 31.86035% of this grid. Prescribed forest, heath, urban-surrogate and wetland vegetation has no simulated assimilation. Those cells remain missing, not zero. `GASST_flag` distinguishes native values, inactive-crop assigned zeros and assimilation not simulated; `crop_carbon_fraction` preserves the .45 grass and .40 maize conversion authority. GPP is a model gross assimilation equivalent, not independently validated ecosystem GPP or NPP.

The main scientific variables use `_FillValue=-999` and `missing_value=-999`. A NetCDF reader with mask/scale enabled returns those as missing; their physical meaning is unchanged from the prior NaNs. Zero remains a valid value. Coordinates and ancillary flags are not additional scientific product variables and do not require extra NetCDF files.

Every file has units, temporal methods, coordinates, CRS, time/depth conventions, model scope, contact, source hashes and Git provenance. `Conventions=CF-1.10` describes the intended metadata convention. A comprehensive external CF checker and STREAM ingestion have not been performed.

## Product database

Rows 2 through 5 of the supplied `Kalmthoutseheide` sheet are completed for the four WENR products. Thirty-two values are edited: dataset name, exact filename, measured byte size expressed in decimal MB, temporal support, variable name, short description, units and no-data value. Existing provider, extent label, resolution, frequency, requested period, planning, deadline, FTP route and contact are retained. Historical planning dates are not a claim of a newly completed FTP transfer. The HL/STREAM configuration, registration, datasource name and ingestion-success columns are unchanged.

The authored row formatting wraps long metadata and filenames. Original sheet names, tables, relationships, shared strings, custom XML and the other two worksheets are preserved. The spreadsheet author uses Artifact Tool; a narrow ZIP/XML preservation adapter merges only the requested authored edits to avoid unrelated round-trip losses. No third-party product database is published in the research repository. Git preserves the WENR changes, workbook identities and reproducible scripts; the completed workbook is returned through the original file identity.

## Reproduce and verify

Recover the two prior candidate source files for 2025 and 2026 from the existing results package or Git parts. Their complete SHA-256 identities are pinned in the repackager. Use a task environment with the versions in `scripts/requirements.txt`:

```sh
python scripts/repackage_by_variable.py /path/to/previous/products /path/to/new_delivery
python scripts/validate_repackaging.py /path/to/previous/products /path/to/new_delivery
```

The independent verifier compares every scientific value, including the missing mask, against source arrays after inverse grid indexing. It also checks the 639 reporting dates, normalised absolute time, daily bounds, exact cell identities, geography, static metadata, actual/requested depths, main-variable count, units, flags and fill-value conventions. Source-to-product identities and byte sizes are in `metadata/product_manifest.json`; results are in `metadata/repackaging_validation.json`.

For workbook reproduction use `scripts/update_product_database.mjs` with Artifact Tool in its supported runtime, the original workbook and `metadata/workbook_changes.json`. It authors the requested cells and formatting and exports an intermediate workbook. Then run:

```sh
python scripts/preserve_workbook_package.py original.xlsx authored.xlsx metadata/workbook_changes.json completed.xlsx
```

The preservation adapter requires `lxml`, available in the workbook runtime. Re-render the completed workbook and inspect the changed rows. The workbook is not needed to reproduce the scientific NetCDF files.

In Git large NetCDF products are split into ordered byte parts under `products/parts`. Run `scripts/assemble_delivery.py OUTPUT_DIRECTORY` to recover the four ordinary `.nc` files, checking every part and complete-file SHA-256 before final rename. Native model reruns and canonical SWAP5 qualification are not selected: this change only reorganises existing results and metadata. The calculations remain provisional and not independently field validated.
