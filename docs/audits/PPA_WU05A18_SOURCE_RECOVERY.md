# PPA-WU05-A18 source recovery — official Andelst macropore profile

Date: 2026-10-01

Status: `SOURCE_PROFILE_AND_PERCHED_TOPOLOGY_RECOVERED / LEGACY_GFORTRAN_RUNTIME_NOT_NUMERICAL_AUTHORITY`

## Package identity

User-supplied package:

- `SWAP_4.3.1.zip`
- SHA-256: `76a79498423ee612a7861efb564b10c4360a4f648396eefcf8e9011919a66039`

Nested exact source archives:

- `tools/SWAP/source/SWAP.ZIP`
- SHA-256: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`

and:

- `tools/SWAP/source/TTUTIL.ZIP`
- SHA-256: `ee40b4bc20b158163318a4a77a1294e0d9430f5cb73641fcf4a2f3c773d01193`

Official case authority:

- `cases/3.macroporeflow/swap.swp`
- SHA-256: `c87ef0f8561f90277a2ae22f74fd12e050e4cafb26cb3b475768a737c76c059b`

- `cases/3.macroporeflow/swap.bbc`
- SHA-256: `ed83fe31870676cef7a57a27ce2372abc53cc0755b0f4ea6b0b6248e152480ff`

## Official Andelst vertical profile

The shipped macropore case uses 112 compartments in eight physical layers:

| layer | thickness cm | compartments | dz cm |
|---|---:|---:|---:|
| 1 | 12 | 12 | 1.0 |
| 2 | 14 | 14 | 1.0 |
| 3 | 8 | 8 | 1.0 |
| 4 | 16 | 8 | 2.0 |
| 5 | 20 | 10 | 2.0 |
| 6 | 50 | 20 | 2.5 |
| 7 | 100 | 20 | 5.0 |
| 8 | 100 | 20 | 5.0 |

Total profile depth: 320 cm.

Official Mualem-van Genuchten parameters:

| layer | theta_r | theta_s | alpha 1/cm | n | l | Ksat cm/d |
|---|---:|---:|---:|---:|---:|---:|
| 1 | 0.055 | 0.405 | 0.0289 | 1.0930 | -10.502 | 1.00 |
| 2 | 0.055 | 0.405 | 0.0289 | 1.0930 | -10.502 | 3.08 |
| 3 | 0.100 | 0.393 | 0.0075 | 1.1080 | -14.455 | 0.17 |
| 4 | 0.010 | 0.395 | 0.0172 | 1.0925 | -5.819 | 1.63 |
| 5 | 0.000 | 0.444 | 0.0117 | 1.0735 | -0.254 | 2.51 |
| 6 | 0.005 | 0.442 | 0.0078 | 1.0870 | -7.713 | 1.25 |
| 7 | 0.010 | 0.525 | 0.0050 | 1.0800 | -7.465 | 1.37 |
| 8 | 0.010 | 0.525 | 0.0050 | 1.0800 | -7.465 | 10.00 |

The official macropore configuration uses `CRITUNDSATVOL=0.1 cm`.

## Local exact-source recovery

TTUTIL 4.27 was rebuilt from the supplied source with gfortran.

The SWAP source requires Intel-preprocessor semantics that gfortran treats as comments.
For local source inspection/build, the standalone non-MultiSWAP branches were selected
explicitly.

Two additional legacy portability defects were encountered under checked gfortran:

1. saturated macropore vertical-flux reconstruction can index compartment zero when
   `icgwl=0`;
2. whole-array assignment of `VlMpDm1Cp` has a 5000-versus-`numnod` shape mismatch.

A separate crop-development defect evaluates `z_tempsow` even when sowing is disabled.

These repairs were used only to continue local source execution. They are **not** treated
as SWAP5 physical authority and are not proposed for canonical admission here.

## Shipped-case census

The unmodified shipped Andelst initial state does not provide a distinct perched body.

At the initial MACRORATE evaluation:

- `NPeGwl=57`;
- `BPeGwl=57`;
- `PeGwl=-80.9 cm`;
- ordinary `Gwl=-80.9 cm`.

Thus the apparent perched carrier duplicates the ordinary groundwater table and does not
satisfy A18's distinct-perched criterion.

## Source-backed perched topology variant

A bounded source experiment retained:

- the exact 112-compartment Andelst discretization;
- all eight official hydraulic parameter sets;
- the official macropore geometry and `CRITUNDSATVOL` semantics.

Only the initial pressure-head profile and lower boundary were changed to construct a
separate perched body and ordinary groundwater table.

The exact corrected CALCGWL/MACRORATE source then reconstructed:

- `NPeGwl=14`;
- `BPeGwl=26`;
- `PeGwl=-13.33333 cm`;
- `PeGwl_bot=-25.83333 cm`;
- ordinary `Gwl=-100.0 cm`.

This is a genuine distinct perched topology under the source carrier and supplies the
A18 topology oracle.

## Why the legacy gfortran run is not the stability authority

After the initial source-defined perched state, the rebuilt legacy executable develops
NaN pressure heads in HeadCalc. The run can subsequently reach its normal-completion path,
but those NaNs invalidate it as numerical evidence.

Therefore A18 uses the legacy execution only for:

- exact profile provenance;
- exact initial/source carrier topology;
- compartment indices and water-level oracle.

It does **not** use that rebuilt run to claim solver stability or perched persistence.

Those claims must be established independently by SWAP5 Reference Richards on the same
112-compartment hydraulic profile.

## Next gate

Construct the 112-compartment Andelst profile directly in the SWAP5 Reference-Richards
testbench.

First run with macropore callback disabled.

Only if that baseline converges and retains the source-defined distinct perched topology
over an accepted interval may the A17 inner callback be enabled.
