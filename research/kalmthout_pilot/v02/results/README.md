# Kalmthout V02 results and SYMPHONICA candidate products

This is a separate results analysis of the immutable regional delivery at commit `48c7897c6500309e5e83377986ca2ff3e20917e3`. It adds thematic maps, temporal and depth comparisons, numeric tables and a source-verified conversion. No native model input, executable or numerical result is changed.

Read `Kalmthout_V02_results_and_SYMPHONICA.md` or the Word edition. Eighteen figures and complete CSV tables support the interpretation. The 2026 available period is partial; April to September provides the common 183-day comparison window.

## Mapping

- ET = 10 × (TACT + EACT + EIC), in mm/day. Pond evaporation is separate, with an additional inclusive diagnostic.
- Soil moisture = 1000 × WC, in kg water per cubic metre of bulk soil. Day-end states remain at the actual centres 10.5, 22.5, 42.5, 82.5 and 162.5 cm.
- GPP = GASST × CFRDM × 1000 / 12 / 10000 × 1000000 / 86400, in micromoles CO2 per square metre per second, as a complete-day mean. CFRDM=0.45 for grass and 0.40 for maize. The source applies the carbon-fraction correction before management/stress reductions; the conversion retains those reductions. Assimilation is missing for prescribed vegetation, which occupies 68.14% of this grid.
- Soil temperature remains Celsius.

The converter is pinned to these V02 source-file hashes. Different crop carbon fractions or a different model version require a reviewed mapping. This is a candidate variable contract, not an approved SYMPHONICA delivery schema. Alignment with standard project datasets remains planned.

## Reproduce

With the original V02 run root available:

```sh
python3 scripts/analyse_results.py /path/to/v02/daily_netcdf /path/to/results
python3 scripts/validate_conversion.py /path/to/v02/daily_netcdf /path/to/results
python3 scripts/plot_results.py
python3 scripts/build_representation_table.py
python3 scripts/write_results_note.py
python3 scripts/build_results_docx.py
```

The first command also reads the original hourly forcing in the sibling `forcing` directory. Plot and document scripts operate on the layout relative to their own script directory. Install the listed dependencies first. The stand-alone converter needs only an original annual NetCDF file; it does not require native reruns or forcing.

In Git the derived NetCDF bytes are stored in parts under `products/parts`; use `scripts/assemble_products.py OUTPUT_DIRECTORY` to reconstruct and verify the three original files. The source native files remain in the earlier V02 preservation set. `products/manifest.json` records every part and whole-file SHA256. The downloadable analysis package contains ordinary assembled NetCDF files.

The water model is provisional, uncalibrated and not independently validated. Strong internal GPP/transpiration correlations are expected from model coupling and cannot serve as validation. All original availability and canopy-accounting flags remain explicit.

## Preparing a comparable note for the next version

Follow the [results-note workflow](workflow/RESULTS_NOTE_WORKFLOW.md) and complete the [next-version record](workflow/NEXT_VERSION_RECORD.template.json). The procedure specifies source and metadata preservation, conversion review, analysis/figure/table coverage, version-specific assumptions, verification and delivery. The current scripts and literal report findings are tied to V02; review and adapt them in a separate version directory.

## Delivery layout agreed on 28 October 2026

The [revised ingestion delivery](delivery_20261028/README.md) provides four NetCDF files, one scientific variable per file, each covering 2025-01-01 through 2026-10-01 inclusive. It retains all 639 daily records and the original values, with exact verified grid reindexing and explicit temporal/depth support. WENR product-database metadata and reproducible packaging/verification scripts are preserved alongside it. The earlier annual files and reports remain the unchanged research reference.
