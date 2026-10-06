# PPA-WU05-MIGMAC10 — exact-source B0 Andelst reference run

Date: 2026-10-06  
Repository checkpoint: `0aba55b13`  
Purpose: recover a reproducible full-case B0 execution baseline; this is not a
SWAP5 equivalence result or production qualification.

## Execution

- Official source distribution: `SWAP_4.3.1(1).zip`, SHA-256
  `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`,
  8,959,314 bytes; both size and digest match `docs/verification/reference-baseline.json`.
- Official case: `cases/3.macroporeflow`; case input was not patched.
- Runner: `tools/vq/b0_source_runner.py` (`b0_exact_source_gfortran`), GNU
  Fortran 13.3.0, runner's documented Linux/compiler-selection compatibility
  transformations, `-O2` build. `SWCSV=1`; no `--disable-csv` compatibility
  patch.
- Result: accepted; process return code 100, `swap.ok` present, `swap.err`
  empty. The run completed over 1998-01-01 through 1999-04-26.
- Ephemeral run directory:
  `/tmp/migmac10-b0-andelst-fullcsv-20261006/run/3.macroporeflow`.

## Frozen input and output identities

| File | SHA-256 |
| --- | --- |
| `swap.swp` | `c87ef0f8561f90277a2ae22f74fd12e050e4cafb26cb3b475768a737c76c059b` |
| `andelst_meteo.998` | `4a78610169f6356ee739ecb939c4e6befb564a2898ea007f6d7421280c01b7d9` |
| `andelst_meteo.999` | `ba5c1f880f6166842ed292c18fd12a142cfda4158002f9487fd1420e734e7b72` |
| `andelst_rain.998` | `a65461b5291bb146033302cc86a13713885585c1a262ed1a4bcb3eab165b7f62` |
| `andelst_rain.999` | `3cc22751f89d46eef91c82607fdba432a2cd32505a9651dc58727ea2f8fd7060` |
| `wintcer1.crp` | `214a3c59a1ec83e2be9bb3889a18ce773cc7730dbd8b23558d0520a764e3fcd7` |
| `wintcer2.crp` | `5818576bb56ff54404af66b9235a83629d7e9480df76bb603d3b2b71a532debe` |
| `result_output.csv` | `bcdfe6222bb1120e19e150e84bde881d2eac519723921b859448577e2f5a519d` |
| `macrogeom.csv` | `67d556114a540ac4e4053f61ff906a85205fef2f96c78faba528e15fda461979` |
| `soilshrinkchar.csv` | `91cb19b0a85c77ab7ced45719dbe121515f7a0db0831a2585b0ce411d535a562` |

The input requests `INLIST_CSV='RAIN,GWL,DRN'`; consequently
`result_output.csv` contains only those daily variables (489 lines including
the metadata and column header). `macrogeom.csv` and `soilshrinkchar.csv` are
static geometry/characteristic outputs, not accepted daily macropore or matrix
states. The standard run does not emit the preregistered daily state, exchange,
receipt, or restart series required for whole-model comparison.

## Output-only expanded reference

To improve the comparison surface without changing physics or forcing, a
separate copy of the official case was run with only these output controls
changed: `INLIST_CSV` requests daily water-balance/top-boundary and standard
macropore scalar fields, and `SWEND=1` writes the end-condition file. The
repository-built B0 executable completed normally (`swap.ok`, empty
`swap.err`, “Swap simulation okay!”). The daily CSV contains 482 records and
43 fields, including daily net rain/irrigation, evapotranspiration, top/bottom
terms, whole-column `WTOT`/`DSTOR`/`BALDEV`, both macropore-domain storage,
exchange, infiltration and top-entry fields, rapid macro drainage and
macropore groundwater level. The terminal end-condition file `result.end`
contains the final `H` profile and restart state.

The extended run preserves the unmodified case's full daily `DATE`, `RAIN`,
`GWL`, and `DRN` sequences exactly (482/482 records); this is a direct check
that the output-only changes did not change those baseline observables.

| Expanded-run file | SHA-256 |
| --- | --- |
| `swap.swp` (output controls only) | `c1b77313755e438ccc2e7aad466df5c16f319832479e269b97061d6b42a49d52` |
| `result_output.csv` | `a31b708add78bc86be630a0b4ab6d6a1d1f84a01ea9bac429223aeaaa8a2f292` |
| `result.end` | `ddd9655d2173b73088644348c429818a6780cdc3c669cc609602cccfa455946a` |
| `swap.ok` | `3fbfb2402cf5d281adbdd5da07cacbae4d846b5586766f87a7ef537f26ce2395` |

This adds useful daily source-owned water and macropore series, but not daily
matrix `H`/`WC` profiles; an exploratory attempt to request vector CSV output
failed the legacy output parser (`Item H ... not known in vars%name`) and was
discarded. The end-state file is a single terminal condition, not a sequence
of accepted restart checkpoints. No SWAP5 profile has yet been paired against
these B0 outputs.

## Interpretation and next gate

This closes the B0-run-execution prerequisite for the official Andelst case and
provides hash-bound daily reference series for water balance and standard
macropore scalar state/flux, plus terminal restart state. It does not establish
equivalence to SWAP5. A matching full-case SWAP5 application/runtime path and
a paired daily matrix-profile/restart trajectory are still absent; without
those, full equivalence cannot be evaluated. The next equivalence work must
first expose equivalent daily matrix state, macropore storage and exchange,
top input/returned receipt, rapid drainage, perched topology when active,
water-balance terms, and restart/replay on both models.

The packaged Intel executable remains unavailable in this environment because
`libimf.so` is absent. The GNU source runner successfully executes the exact
archive identity, but is explicitly a qualification/source runner rather than
a claim of global Intel/GNU equivalence. The archive's `MOD_meteo.f90` also
does not match the pinned B1.11 manifest; B1.11 Boesten equation authority
therefore remains the pinned source/PPA-WU04B contract, independently of this
whole-case B0 reference run.

Production admission remains closed. No canonical source was modified, and no
push or merge was performed.
