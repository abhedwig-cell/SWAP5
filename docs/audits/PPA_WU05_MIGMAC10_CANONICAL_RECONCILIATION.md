# MIGMAC10 canonical reconciliation and full-case boundary

Date: 2026-10-06. Status: bounded local replay; no production admission.

## Pinned postimage

Published work checkpoint `6862528191fde6229bb1d00c6210db7c86dc21f4`
was merged with canonical `78acf56f931763d2e1d4924b3dea0742f231d2e8`
at local merge `7b02c9886d9683328c16ffa30380aba12fb4fd8f`.
The source tree is `711a1a4b4a2dbcd737472c819519a01a3ffc7571`.
The merge has no conflicts and preserves the canonical frost DIVDRA changes.
No new runtime physics, tolerance or admission rule was introduced in this
reconciliation. Recovered work `b1fa35d29` contributes the full FMR bundle
export/restore and next-continuation assertions, supplementing kernel snapshots.

The new `tests/fpm/run_migmac10_b19_preservation.py` is a preservation successor,
not a bypass or rebind of the historical B19 admission runner. It pins the
unchanged canonical B19 test, builder and DIVDRA process, executes all 24 cases
at O0/O2 with the original 8192-step fine continuation and all original
assertions, and requires byte-identical O0/O2 output. The historical B19 source
guard remains unchanged. The B19 build log pins the merged source tree.

## Source identity recovery

All 63 expanded B1.11 source files and all 153 TTUTIL files were verified
against `tests/data/ppa_wu05_migmac01/` manifests before GNU compilation.
In particular `MOD_meteo.f90` matches
`99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f`.
The former missing-source and Intel-library execution prerequisites must not
be repeated as the reason a SWAP5 full-case comparison is unavailable.
The recovered [B0 report](PPA_WU05_MIGMAC10_B0_ANDELST_REFERENCE_RUN.md)
remains a separate source identity and does not substitute for B1.11.

## Official input versus the tested envelope

The census below reads the unmodified official `3.macroporeflow` case, not
`modified_andelst.swp`. Input hashes accompany the replay evidence.

| Official setting | File | Missing composition or application contract |
| --- | --- | --- |
| `SWINTER=3`, `SWREDU=2`, `SWMACRO=1` | Both crop files and `swap.swp` | Three-owner backend lifecycle is tested, but production bootstrap has no combined initialization/layout admission. |
| `SWHEA=1`, `SWCALT=2` | `swap.swp` | Rutter backend preflight rejects `soil_temperature_active`; thermal state and surface composition require separate qualification. |
| `SWBOTB=3`, `SWBOTB3IMPL=1`, `SW3=2` | `swap.bbc` | Rutter backend admits only bottom modes 2/7. The official implicit Cauchy time series is not represented by that envelope. |
| `SWDRA=1`, `DRAMET=3`, `SWDIVD=1` | `swap.swp`, `swap.dra` | Drainage response composition is excluded by the Rutter preflight; source-owned vertical distribution and macropore exchange must share one balance. |
| `SWCROP=1`, `SWDROUGHT=1`, `SWOXYGEN=0` | `swap.swp`, crop files | The seasonal crop/root forcing trajectory is not the small constant synthetic forcing used by the composition tests. No oxygen-stress requirement follows from this case. |
| `SWDRRAP=1`, `Z_TP=0` | `swap.swp` | Rapid drainage is active; this official case is surface-connected, unlike the separately modified covered-top case. |

Exact implementation boundaries are `tile_config_valid` and the initial-state
dispatch in `src/runtime/mod_fmr_production_application_bootstrap.f90`, and the
Rutter preflight in `src/runtime/mod_fmr_serialized_reference_backend.f90`.
The bootstrap explicitly rejects macropores, accepts neither combined layout,
and provides no macropore numerical-policy configuration path. Merely removing
one rejection would neither construct the correct committed state nor configure
the candidate-area Richards route.

## Required successor boundary

Full official-case equivalence needs a separately preregistered shared
application/composition change: typed combined state initialization, explicit
macropore execution-policy wiring, source-window/Boesten forcing ownership,
thermal and implicit-bottom/drainage compositions, and matching accepted daily
matrix profiles, macropore storage/flux, balances and restart trajectories.
The historical parser/file formats need not enter the kernel. Existing thermal,
bottom and drainage owners must be reused, not replaced by legacy global state.

This work must not relabel a heat-disabled, fixed-bottom or externally replayed
flux experiment as unmodified official Andelst equivalence. Such experiments
can only be separately named intermediate qualification cases. The bounded
MIGMAC10 results do not authorize widening those shared application contracts.
State ownership, trial isolation, restart fidelity, exactly-once mass booking,
physical-option/numerical-policy separation and Reference availability remain
fixed (invariants 3, 7, 13, 23, 25, 27, 29).

## Completed local evidence

Merged composition and FMR-bundle restart, Boesten/Black/bootstrap/common
forcing preservation, A10, MIGMAC09, PERCH20 and all 24 B19 cases pass at O0/O2.
The exact B1.11 full Andelst run exits with the expected success code 100,
writes `swap.ok`, and removes the empty error file on normal completion.
Its 482 `DATE/RAIN/DRN/GWL` records are identical to the recovered B0 run.
This four-field comparison is not a full-state or SWAP5 equivalence claim.

`tests/qualification/ppa-wu05-migmac10-canonical-20261006/reconciliation.json`
binds source identity, compiler, executable hash, all source-manifest checks,
case inputs, outputs and compressed gate logs. B19 raw output and receipts are
included. Both documentation checks pass. Full official SWAP5 execution remains
blocked at the explicitly documented shared application/composition boundary.
