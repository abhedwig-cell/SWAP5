# PPA-WU05-A10 result — FMR macropore rapid drainage

Date: 2026-10-01

Status: QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE

Baseline: `integration/f-ci-canonical@7db09b56deb99decf32f47d2deed72710a04e8b5`

Qualified code/test postimage: `2714c755c50e1ea1ea3bb4e6fc466ce21c9f4e80`

Qualification workflow: `.github/workflows/ppa-wu05a10-rapid-drain.yml`

Qualification run: `36829166995` — SUCCESS

## Qualified scope

A10 binds the already source-bound A6 B1.11 rapid-drain process into the canonically admitted A8/A9 serialized single-column Reference-Richards macropore runtime.

Qualified:

- standard `swmbf=1`;
- serialized single-column FMR;
- Reference Richards;
- rapid drainage in main macropore domain 1;
- immutable drain type, drain level, area exponent, reference conductance and reference resistance;
- drain level aligned to an FMR compartment boundary;
- dynamic top-water node, saturated top fraction, macropore water level, ponding, active main-domain bottom and main-domain volume reconstructed each trial;
- exact reconstruction of main-domain macropore volume below the aligned drain level;
- storage-limited multi-compartment rapid drainage through the existing A6 implementation;
- one external rapid-drain accepted mass owner;
- simultaneous A9 source-faithful top input.

## Source and implementation boundary

A10 does not reimplement RAPIDDRAIN. `mod_ppa_wu05a6_rapid_drain_rate` remains the equation authority established by A6/A5.

A10 changes only the production composition:

- bounded rapid-drain configuration is admitted in `fmr_macropore_physical_config_t`;
- `mod_macropore_standard_rate_adapter` reconstructs the dynamic request fields from current hydraulic/macropore views;
- the serialized backend books `rapid_external_outflow_cm` exactly once as external mass outflow;
- observation diagnostics expose rapid-drain activation and accepted amount.

## Qualification evidence

The exact A6 source oracle is preserved:

`PPA_WU05A10_RAPID_DRAIN=PASS`

Real serialized FMR trial:

`PPA_WU05A10_FMR_MACRO_TRIAL|MASS=-0.33306690738754696E-15|MACRO_BEFORE=1.6000000000000001|MACRO_AFTER=1.0739249779550462|RAPID_OUT=0.11121147871735207`

Active rapid-drain reject/restart/replay trial:

`PPA_WU05A10_REPLAY_TRIAL_DIAG|STATUS=0|COMPLETED=T|TEMP_SOURCE=1|TEMP_REJ=11|MASS_REJ=0|SOLVER_REJ=0|MASS=-0.94368957093138306E-15`

The temporal rejections are handled by the existing external full/half transaction contract; there are zero mass and solver rejections.

The gate proves:

- candidate-only publication;
- discard without committed mutation;
- checkpoint replay;
- commit;
- persistence export/restore;
- restart continuation and identical next candidate;
- O0/O2 output identity.
- an unaligned within-compartment drain level is rejected by production configuration validation;

## Preservation

The same focused gate preserves:

- A7 real Reference-Richards runtime;
- A8 serialized FMR, reject/replay and restart;
- A8 zero-top-input real FMR trial;
- A9 source-faithful top-input trial;
- A9 top-input reject/replay and restart.

## Deliberate non-admitted scope

A10 does not admit:

- perched-zone macropore physics;
- arbitrary drain levels cutting through a compartment;
- multiple rapid-drain levels;
- fixed-weir/Ribasim ownership of this same rapid-drain receipt;
- dynamic crack-geometry displacement feedback inside the same corrector;
- RossFast;
- parallel/concurrent MultiSWAP.

## Lifecycle

`implemented -> persisted -> tested -> qualified`

Canonical admission and closure are not claimed by this record.
