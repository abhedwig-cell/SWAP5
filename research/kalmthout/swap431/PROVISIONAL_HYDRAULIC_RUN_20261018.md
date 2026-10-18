# KALM-S431-01 provisional same-hydraulics bare-soil experiment (2026-10-18)

**Executed locally: engineering pass, not a location-specific Kalmthout qualification.**

## Rationale and authority
Sibling branch `work/kalmthout-pilot-current-20261017`, source `research/kalmthout_pilot/kalmthout_swap5_pilot.f90`, config `initialize_parameters` shows **synthetic uniform hydraulic parameters**, no root extraction, no drainage, no frost etc. Do not claim sampled Kalmthout soil properties or vegetation. Source is an experimental SWAP5 pilot, not a qualified site authority.

The SWAP4.3.1 testcase derived from copied Hupsel example uses:
- Same 24,120-hour actual ERA5 pilot forcing (2024-01-01 to 2026-10-01 UTC), rainfall 221.66 cm, `SWETR=0`, `SWRAIN=3`.
- `SWCROP=0` bare soil; `SWDRA=0`; `SWHEA=0`; `SWBOTB=6` zero bottom flux; `SWIRFIX=0`; `SWHYST=0`; `SWSOPHY=0`; `SWKMEAN=1`.
- Uniform MvG values for the two legacy soil physical layers: ORES 0.032, OSAT 0.423, ALFA 0.0135 cm-1, NPAR 1.455, LEXP 0.365, KSATFIT 4.75 cm/d. These match the numeric coefficient values used by the experimental SWAP5 pilot; Ksatexm was set to 4.75 cm/d, with corresponding legacy warning. 
- Original Hupsel vertical geometry **not** made equal to SWAP5 vertical topology; legacy init `SWINCO=2`, `GWLI=-75 cm` **not** identical to SWAP5 uniform `H0_CM=-75 cm`; legacy ponding/runoff settings partly aligned (PONDMX 1 cm, RSRO 0.1 day), but surface contracts are not proven equivalent.
- Retained other inherited legacy switches not yet independently audited. No deliberate tuning against output.

## Execution
Local `gfortran` SWAP4.3.1 executable `/mnt/data/kalm431/build/swap_gnu`. Case `/mnt/data/kalm431/real/swap5_hydraulic_bare_soil`.
Full requested period ran and `swap.log` ended `Swap simulation okay!`, with `Swap normal completion!` (legacy process return 100); runtime 1.62121904 sec.

Annual water balances (cm; original model output print precision):
| year/period | P | runoff | soil evaporation | bottom flux | storage change | residual P - outputs - delta S |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 2024 | 107.09 | 43.44 | 59.96 | 0 | +3.70 | -0.01 |
| 2025 | 60.07 | 24.40 | 35.82 | 0 | -0.15 | 0.00 |
| 2026 through 1 Oct | 54.50 | 15.85 | 38.71 | 0 | -0.07 | +0.01 |

Residuals are differences of values printed to 0.01 cm, not machine-precision model residuals. High runoff is strongly boundary-dependent with zero bottom flux, and should **not** be interpreted as site prediction. The legacy third output block has a mismatched period heading; date labeling is not yet qualified. Warnings: Ksatexm input and large dz for solute calculation.

## Qualification boundary / follow-up
This is a significant improvement over the Hupsel-parameter technical run, but it is still **not a valid SWAP4-SWAP5 numerical equivalence comparison**: different vertical grid, initialization, atmospheric process handling, possible top boundary semantics and Hupsel-inherited controls. No measured Kalmthout soil profile or vegetation class has been established. Need independent soil/land cover data and/or precisely matched two-code benchmark configuration before physical scientific use.

No new GitHub Actions used. Canonical unchanged.
