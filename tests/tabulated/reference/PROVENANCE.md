# F-TAB01 legacy interpolation oracle provenance

This directory contains an **isolated test oracle**, not production SWAP5 source.

## Oracle source

- upstream repository: `SWAP-model/SWAP`
- upstream commit: `c22bd832ddf3e53e330a552f5e31e74f183362d1`
- upstream path: `src/soil/sptabulated.f90`
- upstream Git blob: `62a4df82de75f1231fe066351473d140cf2ac31c`
- original embedded SVN id: `sptabulated.f90 366 2018-01-10 11:12:43Z kroes006`

The same Git blob is present on the upstream modernization lineage at commit
`24f56033f`, immediately before the tabulated path was retired to a dormant
location on 2026-05-24.

This provenance does **not** claim byte identity with the private/supplied SWAP
4.3.1 distribution used for the SWAP5 B0/B1 reference line. It is used only to
characterize the preserved historical interpolation algorithm while the exact
4.3.1 table-source identity remains unbound in this work unit.

## Harness scope

The harness compiles the oracle with a reduced array-dimension stub and
generates synthetic tables from a default unimodal MvG relation matching the
form of the admitted SWAP5 analytical denominator.

No file I/O, application physics or production runtime is exercised.

The first run is characterization, not an admission gate. It reports:

- maximum absolute and range-normalized theta error;
- maximum log10(K) error in decades;
- capacity error on the smooth analytical branch;
- derivative self-consistency of theta and K interpolants.

Only structural invalidity (non-finite values, theta outside physical bounds,
or non-positive K) makes this first characterization fail.
