# PPA-WU05-MIGMAC11 pond-derived macropore donor

Date: 2026-10-06. Status: IMPLEMENTATION_IN_PROGRESS.

## Source contract

Pinned B1.11 authority is
`reference/swap-4.3.1/b1_11_frost_source/SWAP/boundtop.f90`.
Lines 115 and 155-163 establish the ordering. Matrix supply is direct
rain/irrigation/melt times `1-ArMpSs` plus runon minus evaporation. Only after
the no-macro pond candidate `h0max` is known does the source derive
`QMpLatSs` from `PndmxMp`, `KsMpSs`, `p1`, `dt` and the already
partitioned direct macro input. The amount is capped by `h0max` and amounts
below 1e-7 cm are zeroed.

`PONDRUNOFF` then subtracts `QMpLatSs/dt` from the same surface balance and
recomputes ponding/runoff. Capacity-rejected macro input may subsequently return
through the existing macropore receipt. Runon is not a direct macropore source.

## SWAP5 seam

MIGMAC10 already makes candidate `ArMpSs` available before dynamic-top
evaluation through the inner macropore provider. MIGMAC11 must extend that same
residual-synchronous seam. A pre-step calculation from committed ponding would
be source-inconsistent.

The first production primitive in
`src/runtime/mod_fmr_macropore_top_input.f90` now implements the literal
B1.11 155-163 algebra only. It deliberately does not mutate ponding, inject
runon, or claim admission. The next step is a bounded dynamic-top donor receipt
and a same-residual handoff to A9's existing lateral limiter/return owner.

## Required closure evidence

Dry, threshold, wet, source 1e-7 cutoff and fail-closed conductivity cases must
pass O0/O2. The integrated route must additionally prove candidate-area
synchrony, accepted donor debit, capacity-return restoration, reject/retry,
restart/replay, whole-column mass closure and preservation of MIGMAC09/10.
Runon composition follows only after the no-runon donor route passes.
