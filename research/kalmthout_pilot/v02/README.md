# Kalmthout SWAP 4.3.1 V02

First provisional regional technical exercise for SYMPHONICA. All 4,096 independent 250 m columns cover 2024-01-01 through 2026-10-01 with hourly forcing. Numerical heat is enabled throughout; 802 grass and 503 maize-proxy columns use WOFOST. This is not a calibrated regional hydrological model or SWAP5 admission.

## Read and recover

The detailed English technical note is in `docs/Kalmthout_V02_technical_note.md` and its Word edition. The note explains sources, exact run construction, output definitions, quality flags and proposed improvements. Machine-readable schemas and identities are under `metadata`.

All original native inputs and outputs, source closure, complete V01 recovery and the three final annual NetCDF files are preserved as binary parts under `evidence`. Parts keep each Git object below the existing 7.2 MB research packaging size. Assemble and verify them locally:

```sh
python3 research/kalmthout_pilot/v02/scripts/assemble_artifacts.py /absolute/path/assembled
```

The script reads the ordered manifest, checks every part and the complete SHA-256 and only then renames each assembled file. Extract the complete V01 and V02 archives into separate empty directories. The Word note provides subsequent native audit, export and rebuild commands. Use the complete baseline archive supplied here; the older two-part V01 archive outside this directory is a historical 69-case checkpoint.

## Evidence boundary

`metadata/delivery_validation_v02.json` records 2,395 unflagged native completions and 1,701 completions with explicit canopy-reset accounting flags. No failed column remains. Known daily physical closure limitations have not been hidden by altering native water fluxes or solver tolerances. Groundwater surroundings, dominant terrestrial treatment of mixed cells, maize proxy, initial states and parameter transfer remain provisional.

We intend to align these exploratory inputs and outputs with the standard datasets collected and made accessible within SYMPHONICA. That alignment and independent observational validation have not yet been completed.

The implementation changes only the research files and the retained SWAP 4.3.1 output module. No canonical SWAP5 interface or architecture invariant is changed. No mass-conservation condition is relaxed. See `STATUS.json` for the recoverable work-unit boundary and `metadata/artifact_manifest.json` for exact archive identities.
