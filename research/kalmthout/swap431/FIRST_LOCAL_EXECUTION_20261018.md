# KALM-S431-01 first local execution evidence (2026-10-18)

## Confirmed

- User-provided SWAP_4.3.1.zip SHA-256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`.
- Nested SWAP.ZIP SHA-256: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.
- Distributed Linux executable SHA-256: `e3b45c1fe66a614c1caead4b2fc0684a09165672a32d8d3bf4eac00498767862`.
- Original Linux executable could not start: missing Intel runtime `libimf.so`.
- All 63 Fortran SWAP members compiled locally with `gfortran` (GNU 14.2.0). The separate working build copy converted Intel `!DEC$` conditional source directives to GNU preprocessor directives. The original B0 archive was not modified.
- Supplied Intel-built `ttutil427.a` did not GNU-link; all TTUTIL source members compiled separately with GNU Fortran, and the full GNU executable linked successfully.
- Example case `cases/1.hupselbrook` originally failed output setup: `ERROR in csv_write: Item S_CONC in userlist not known in vars%name`. In a **copy of the case**, `SWCSV` was changed from 1 to 0, isolating the optional output configuration error.
- Re-run of Hupsel in the copy completed the full 2002-01-01 through 2004-12-31 interval. `swap.log` ended in `Swap simulation okay!` with reported runtime 1.55298495 s; the program returned process code 100, which should not be interpreted as success by generic Unix convention absent its documented SWAP stop semantics.
- Generated yearly water-balance output `result.bal` and `result.blc` for 2002, 2003 and 2004. First year 2002: inflow 86.58 cm, outflow 83.76 cm, storage change +2.82 cm, agreeing to printed precision. Other two years require explicit numeric closure evaluation.

## Qualification boundary

This is a local GNU-translated-source **engineering smoke test**, not execution of the untouched B0 Intel binary and not a Kalmthout run. B0 byte identity is proven for the supplied input archive, but GNU conversion/toolchain effects have not been scientifically qualified against the Intel build. No evidence for Kalmthout forcing availability, parameter parity or complete 2024-2026 run has yet been established.

## Next step

Recover actual Kalmthout weather and column parameters from the sibling Kalmthout workstream, build a case with a provenance manifest and carry out one-day to full-period experiments. Do not substitute Hupsel meteorology for Kalmthout.
