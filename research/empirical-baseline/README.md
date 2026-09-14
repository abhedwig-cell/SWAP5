# SWAP 4.3.1 empirical baseline capability

Status: active isolated research/verification capability. This directory has no production authority.

## Purpose

Record what the qualified SWAP 4.3.1 reference lineage actually does before using that behaviour to judge SWAP5 refactors. The baseline is observational: execute pinned reference-derived code, persist the observation surface, and separate observed behaviour from later architectural interpretation.

This capability deliberately does not reuse the historical `work/eb-*` name family because those branches are the energy-balance line. Here `empirical baseline` means behavioural reference evidence.

## Pinned starting point

- canonical integration start: `d44b2eb48e7187f8ddc622a5f2329d7a24c24aa0`
- B0 distribution SHA-256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`
- B1.10 source-manifest SHA-256: `2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`
- restricted reference-ET process blob: `f5e88ec5089fd3b57ac111065fab2aa32dde0fae`
- inherited F-PM06A successful workflow run: `34449186836`

The process blob is byte-identical to the module exercised by the successful F-PM06A candidate run. Evidence is inherited only while that blob and the interpretation boundary below remain unchanged.

## Baseline order

The capability is built in this order: forcing, reference evapotranspiration, soil water and fluxes, boundary conditions, drainage, solute, crop/LAI, output and diagnostics. Multiple slices stay on this branch unless a real scientific or architecture contract boundary requires isolation.

## Slice EB-R01: restricted forcing and reference-ET observation

EB-R01 observes the already qualified B1.10-derived restricted ET route represented by `mod_reference_et_demand_process`:

- `SWETR=1`
- `SWMETDETAIL=0`
- `SWCFBS=0`
- `SWINTER=0`

The executable observer varies reference ET, crop emergence, vegetation cover, crop factor, CO2 factor and pond factor. It records potential transpiration, soil evaporation and pond evaporation. The workflow compiles and runs the exact pinned module at `-O0` and `-O2`, requires byte-identical textual observations, and independently checks the expected numerical anchor cases.

This is an empirical execution baseline for the restricted reference-ET demand surface. It is not yet a full empirical forcing baseline and it is not a full SWAP 4.3.1 distribution run.

## Full-distribution boundary

The canonical B0 archive is identified and verified but is not stored as a byte-exact unpacked Git tree because `MOD_RIA.f90` contains non-UTF-8 bytes. Therefore this capability must not claim that a run of the text-oriented legacy port is equivalent to executing the complete supplied SWAP 4.3.1 distribution unless that equivalence is separately demonstrated.

When the exact `SWAP_4.3.1.zip` or nested canonical `SWAP.ZIP` is available to the runner, the existing B1.10 reconstructor can be used to add full-model observations without changing this evidence model.

## Stop rule for EB-R01

EB-R01 is closed only when all of the following are true:

1. the observer is committed on this capability branch;
2. the qualified process blob still equals `f5e88ec5089fd3b57ac111065fab2aa32dde0fae`;
3. `-O0` and `-O2` observations are identical;
4. all numerical anchor cases pass;
5. the successful workflow run ID and observation SHA-256 are persisted in `EB-R01_STATUS.md`.

No production source is changed by EB-R01.
