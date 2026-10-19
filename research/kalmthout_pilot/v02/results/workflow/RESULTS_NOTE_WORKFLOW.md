# Reusable Kalmthout results-note workflow

Status: **Preserved V02 method and requirements for a future version**, 19 October 2026. This is a research reporting procedure, not a new physical contract or a canonically admitted SWAP5 capability. It affects no canonical architecture invariant. No native computation is selected for this documentation and recovery change.

## Start here in the next session

Read [the results status](../STATUS.json), [the results README](../README.md), this procedure and the new simulation version's own status record. Pin the exact input commit and the exact analysis-code commit. Preserve a new version directory; do not replace V02 inputs, report or evidence. The reference simulation is `48c7897c6500309e5e83377986ca2ff3e20917e3`; the completed reference results are at `50975c8f2cc9351de56b4f0d9e1f6df5db45c87e`, under `research/kalmthout_pilot/v02/results`.

Copy [NEXT_VERSION_RECORD.template.json](NEXT_VERSION_RECORD.template.json) into the new version's evidence directory and fill it as work proceeds. It is a recording template, not an implemented pipeline configuration or a validation schema. Leave unknown facts null and readiness false until the owning evidence exists. Record the commit containing the completed record through Git, rather than embedding its own hash recursively.

The target is a separate, extensive English results note with maps, time series, depth and crop comparisons, numeric tables, explicit interpretation limits and a reproducible SYMPHONICA variable mapping. Retain the construction note separately. Update prose from the new results; a successful script run does not establish that the old scientific interpretation still applies.

## What must be preserved before analysis

| Record | Required contents and reason |
| --- | --- |
| Source identities | Ordered final NetCDF files, byte sizes and SHA-256; completion receipts; native input, executable and source-code identities; source and analysis Git commits. Ignore `.partial` files. |
| Period and clock | Inclusive simulation dates, counts, calendar, UTC or other timezone, exact time units and interval bounds. Identify complete and partial months/years. State whether coordinates label start, centre or end of interval. |
| Spatial support | CRS and vertical datum or explicit unknown; cell IDs, coordinates, row/column order, resolution, area and domain mask; native cells versus reporting units. Preserve links to source soil and land-cover data and their versions. |
| Representation | Vegetation class and active crop model per cell, class counts/area, mixed land/water fractions, soil imputation and surrogate flags. Preserve lower-boundary assignments and all management/calendar assumptions. |
| Depth support | Requested depths and actual compartment centres, sign convention, units and any interpolation method. Preserve layer boundaries/thicknesses if calculating a profile stock. |
| Forcing | Exact meteorological input and hash, source/retrieval version, field units, time ordering, missing-data handling, spatial support and hourly-to-daily aggregation. |
| Native variable semantics | Unit, sign, accumulation/reset logic and physical meaning of every input field used, from the executed source. Record whether it is a flux integral, interval mean or end-of-step state. |
| Carbon authority | Executed assimilation and output source excerpts with hashes, active crop files and CFRDM/RELMF, water-stress handling and GASST reset interval. Time-varying rotations require time-varying carbon-fraction authority. |
| Physical assumptions | Initial hydraulic and thermal states, spin-up, lower/lateral boundary treatment, drainage, irrigation, frost, interception and heat options. Distinguish disabled processes from a process whose simulated value is zero. |
| Quality | Run completion/failure and accounting flags, assimilation availability, native balance definitions, known discrepancies and validation scope. Keep missing, inactive zero, failed and valid values distinguishable. |
| Environment | Python/package versions, external rendering tools/fonts where relevant, commands and logs. Record source-to-output manifests and hashes for the final postimage. |

The existing [conversion contract](../evidence/conversion_contract.json), [GPP source derivation](../evidence/GPP_source_derivation.json), [analysis summary](../evidence/analysis_summary.json) and [conversion validation](../evidence/conversion_validation.json) exemplify the minimum evidence. Preserve equivalent new records, not copied PASS labels.

## Review the mapping before accepting a new input

| Candidate product | Preserved V02 rule | Review for the next version |
| --- | --- | --- |
| ET | `10*(TACT+EACT+EIC)`, mm/day for native daily cm integrals | Confirm component units, signs and reset intervals. EIC includes native canopy-reset accounting; retain flags. Preserve EPD separately and `ET_including_pond=ET+10*EPD`. Agree project scope for pond-water evaporation. |
| Soil moisture | `1000*WC`, kg water per cubic metre of bulk soil | Confirm volumetric input and water-density assumption. Do not multiply by soil bulk density or call this kg/kg. A profile water stock needs layer thickness, not a sum of point values. |
| GPP | `GASST*CFRDM*1000/12/10000*1e6/86400`, micromoles CO2 per square metre per second | Re-derive from the executed model. V02 GASST is kg assimilate equivalent per hectare per day; CFRDM is .45 for grass and .40 for maize. The result is a positive-uptake full-day mean retaining native management and stress reductions. It is not NPP, daylight mean, instantaneous flux or full ecosystem coverage. |
| Soil temperature | Native T unchanged in degrees Celsius | Confirm native units, actual depths and end-state timing. Convert Kelvin only if the new input is actually Kelvin. |

The V02 converter deliberately rejects source files outside its three pinned hashes. New hashes must not simply be added to bypass this guard. First check semantics, grid, crops, depths, intervals and flags; preserve the new mapping decision and then adapt a versioned converter. For variable intervals, obtain duration from bounds; the V02 implementation asserts exactly 86,400 seconds and is not a general subdaily converter. Confirm calendar and unit decoding before deriving seconds from numeric bounds.

Use `umol m-2 s-1` as the physical GPP units and record `substance=CO2` separately, with temporal support and uptake sign explicit. A CF convention attribute is a declaration; claim external CF validation only if a checker has actually run. Official SYMPHONICA schema and standard-dataset alignment remain separate review tasks.

Retain NaN where assimilation is not simulated. V02 GPP is represented in 1,305 of 4,096 cells. Never turn unsupported forest/heath assimilation into zero or extrapolate a crop mean across them. Report represented area beside every landscape carbon summary. For new grids, calculate coverage again.

## Build analyses with explicit denominators

1. Validate completed-file hashes, time continuity, unique cell IDs, expected dimensions and consistency of metadata across annual partitions. Check the forcing dates against simulation dates before joining them. V02's hourly aggregation assumes an ordered, uninterrupted 24-record UTC day; this must be checked or replaced for another input format.
2. Use an agreed common complete window for year comparisons. V02 uses April 1 through September 30, 183 days in each of 2024, 2025 and 2026. Preserve full available-period totals separately and label 2026 partial. Compare wet/dry/warm conditions within the available record; climatological ranks require a suitable external reference period.
3. State the reporting mask, cell counts, represented area, weighting and missing-value policy for each statistic. V02 uses equal-area cell means. New unequal-area grids require area weighting. Avoid `nansum` converting an entirely missing population into a plausible zero.
4. Integrate flux rates over interval duration, then convert units. Sum daily mm to period mm; integrate GPP using seconds, divide by one million and multiply by 12 for g C/m². Average moisture and temperature states; do not sum them as fluxes. Use actual depth support.
5. Form stress ratios as `sum(TACT)/sum(TPOT)` for the same population/window, not the mean of daily ratios. Mark a zero denominator missing. Preserve bottom-exchange sign; native BOT is positive into the column in V02, so net bottom outflow is `-10*sum(BOT)`.
6. Keep period accounting explicit, including pond evaporation, runoff, irrigation, drainage, bottom exchange, storage change and native BALDEV as applicable. Distinguish native accounting from a residual reconstructed from consecutive printed stores. Do not relabel bottom drainage as validated aquifer recharge.
7. Calculate depth profiles, seasonal state summaries, dry-date maps, temporal extrema and temperature damping/peak timing. Define whether an extremum concerns a cell, a spatial mean or the whole sample. A difference between annual peak dates is not automatically a heat-pulse travel time.
8. Retain per-cell results and unrounded tables. Display rounding must not become a calculation input. Use smoothing only for display and identify its window. Spatial percentile bands describe spatial variation in this deterministic run, not confidence limits.
9. Compare vegetation/crop and boundary groups with their counts and area. Label proxy crops, urban surrogates and tiny classes. High wetland ET under prescribed shallow heads needs the associated upward boundary supply in the interpretation. Shared meteorology and absent lateral flow constrain causal attribution.
10. Screen alternative reporting populations separately from a sensitivity experiment. Excluding mixed, imputed or surrogate cells changes the sample; it does not rerun physics or quantify total model uncertainty. Strong GPP/transpiration coupling is partly imposed by model equations and is not independent validation.

## Required report content and figure inventory

Use the V02 note's level of detail as a reference, with a self-contained summary and a short comparison against the previous version on common support. The report should cover the simulation/coverage context; conversion definitions; weather contrasts; water accounts and ET components; spatial and class response; moisture by depth; temperature by depth; assimilation and coverage; representation/flags; validation; product metadata and practical use; limitations and next steps. Add monthly accounting and provenance appendices. Explain what changed in the model or input data before interpreting changes in output as environmental change.

| V02 figure | Purpose to retain or explicitly replace |
| --- | --- |
| 01 domain and model routes | Vegetation/crop assignments and selected input-quality limitations |
| 02 monthly weather | Rainfall and air temperature; preserve radiation in supporting tables |
| 03 period water balance | Available periods alongside matched seasonal budgets |
| 04 evaporation time series | Transpiration, soil and canopy contributions |
| 05 class evaporation/input difference | Class time series and cumulative rainfall minus evaporation |
| 06 seasonal ET maps | Common colour scales and difference maps |
| 07 class ET components | Component totals by class and common season |
| 08 transpiration ratios | Seasonal progression of actual/potential response |
| 09 moisture depth/time | Temporal profiles with spatial P10 to P90 |
| 10 moisture month/depth | Seasonality and attenuation with depth |
| 11 class depth profiles | Matched winter/summer depth profiles |
| 12 dry-date spatial moisture | Same-date maps across actual depths |
| 13 soil temperature/time | All depths with explicit temporal support |
| 14 temperature depth/amplitude | Depth dependence of range and seasonal timing |
| 15 crop GPP/time | Separate crop panels, full-day means and missing periods |
| 16 GPP space/coverage | Assimilation values alongside represented-area mask |
| 17 carbon/water relations | Relationships and model-coupling caveat |
| 18 accounting flags | Daily residual magnitude and affected-cell counts |

Captions must name variables, units, population, period, depth and smoothing where relevant, and explain the finding's limit. Check axis clipping, discrete mask colours, legends, missing-data colour and geographic orientation. Fix colour scales across compared maps; give units to difference maps. Derive domain extents and raster shape from the new grid rather than copying V02's 64 by 64 layout.

Preserve these twelve table families: `annual_domain`, `common_period_domain`, `annual_and_seasonal_classes`, `monthly_domain`, `depth_statistics`, `spatial_ET_ranges`, `cell_results`, `weather_comparison`, `extremes`, `thermal_depth_metrics`, `carbon_water_diagnostics` and `representation_sensitivity`. Define periods and denominators in headers/metadata. V02's last table is generated by [build_representation_table.py](../scripts/build_representation_table.py), including the zero-water condition for the dominant-fraction subset. Review class codes and flag vocabulary for a new version.

## Reproduce V02, and what must be adapted for a new version

The executable sequence below is for a checkout containing these scripts and the reconstructed native V02 run root. Paths are examples for directories the operator must supply. First recover preserved files with [the V02 assembler](../../scripts/assemble_artifacts.py) and inspect [the V02 README](../../README.md). Extract the verified V02 archive to a separate directory; its `daily_netcdf` directory must contain `netcdf_export_receipt.json`, and its sibling `forcing` directory must contain `hourly.met`.

Run from the repository root. The analysis writes to the directory containing the copied reporting scripts because the plot and authoring scripts resolve their own parent directory:

```sh
REPORT_ROOT=research/kalmthout_pilot/v02/results
SOURCE_NETCDF=/absolute/path/to/recovered/v02/daily_netcdf
python3 -m pip install -r "$REPORT_ROOT/scripts/requirements.txt"
python3 "$REPORT_ROOT/scripts/analyse_results.py" "$SOURCE_NETCDF" "$REPORT_ROOT"
python3 "$REPORT_ROOT/scripts/validate_conversion.py" "$SOURCE_NETCDF" "$REPORT_ROOT"
python3 "$REPORT_ROOT/scripts/plot_results.py"
python3 "$REPORT_ROOT/scripts/build_representation_table.py"
python3 "$REPORT_ROOT/scripts/write_results_note.py"
python3 "$REPORT_ROOT/scripts/build_results_docx.py"
```

Use a disposable checkout for reproduction. These commands regenerate V02 files and may overwrite evidence/report files; use a separate version directory for future work. `validate_conversion.py --rebuild` explicitly rebuilds derived products and is unnecessary after the analysis has already converted them. The plotting script also writes four supporting CSV tables. The representation script must precede prose generation. The Markdown and Word writers do not run the scientific analyses themselves.

The current scripts are a preserved V02 implementation, not a version-independent reporting framework. Adapt at least:

- `convert_symphonica.py`: source identity guard, baseline/version strings, variable semantics, carbon fractions, interval assumptions, copied metadata, dimensions and chunk shape.
- `analyse_results.py`: input receipt, class codes, periods, forcing parser, common windows, fixed complete-cell-day count and baseline labels. Validate metadata consistency across partitions.
- `validate_conversion.py`: years/filenames, class semantics, interval assumptions and independent carbon checks. Do not import the converter's factor as the only verification of that factor.
- `plot_results.py`: year lists, 64 by 64 reshape, fixed extents, selected comparison year, class assignments, expected coverage text and partial-month exclusions. Adjust scales if new data exceed them.
- `build_representation_table.py`: classes, imputation vocabulary, population definitions and reference year; its default 2025 column name is part of the old writer's interface.
- `write_results_note.py`: all fixed findings, dates, numbers, captions, coverage statements, period descriptions and filenames. Several numeric findings are literal prose; they do not update automatically when tables change.
- `build_results_docx.py`: output name, date, running header/footer and any figure/table layout changes. Regenerate and review pagination after changes.

Preserve updated dependencies and commands. No silent global replacement of V02 with V03 can establish scientific correctness. If a new configuration requires additional analyses, add them and explain departures from the reference inventory.

## Verification and publication gates

- Require complete-array conversion checks for all cells, intervals and depths. V02 checks exact float64 ET and unchanged temperature, moisture rounding below `4e-5 kg/m³`, and GPP inverted independently to native carbon within `atol=2e-14, rtol=2e-15` in daily g C/m². Reassess tolerances for new precision and magnitude; record the reason for any change.
- Check copied IDs, coordinates, requested/actual depths, bounds, dates, availability and canopy flags, plus unit strings and sign conventions. Preserve valid zeros and missing cells separately. V02 checks some coordinate identities directly; broader schema claims need broader checks.
- Reconcile table totals against native quantities and common-window day counts. Reproduce the representation screen with `python3 "$REPORT_ROOT/scripts/build_representation_table.py" --verify`.
- Keep verification receipts for the exact delivered file hashes. Record source excerpts and hashes for the conversion authority. Run a schema/CF checker if such compliance is required, and retain its actual result.
- Render the final Word file and visually inspect every page, including all figures, legends, repeated table headers, equations, clipping and page breaks. Record actual reviewed pages, figure/table counts and the delivered report hash. Old render receipts do not cover an edited document.
- Version scientific scripts, requirements, Markdown and Word reports, numeric tables, figures, compact aggregate arrays, mapping/source evidence, manifests, validation logs and a recoverable status record. Keep previews, contact sheets, caches, credentials and transfer helpers out of the delivery.
- Preserve large NetCDF bytes using ordered parts plus per-part and whole-file hashes, following the current repository packaging convention. Verify reassembly with [assemble_products.py](../scripts/assemble_products.py). The download package should contain ordinary assembled files, with no duplicate part set. Preserve package inventory and checksum when producing a new package.
- Check repository documentation sources and strict MkDocs build for documentation changes. Use proportional scientific checks for changes to the analysis or model; documentation alone does not select native solver reruns or a full F-CI campaign.
- Confirm the remote commit and branch after writing Git. The final handoff names exact input/analysis refs, status and recovery paths, completed versus pending checks and the next safe scientific step.

Retain explicit improvement priorities: surrounding groundwater/surface-water representation; hydraulic and thermal spin-up; standard project datasets, identifiers and schema; actual crop/management and forest/heath assimilation; mixed-cell and soil-parameter treatment; independent hydrological, moisture, temperature and carbon observations. Add priorities suggested by new results. This remains a technical exercise until the evidence supports stronger claims.
