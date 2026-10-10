# Small-gap qualification reclassification, 6 October 2026

Baseline authority: master coverage branch `work/swap431-master-coverage-20261006` at `180f4760608038999e03079a6ba79d16cdcb32e3`.

This record changes queue semantics only. It creates no production implementation and no admission.

## Decision

Four entries previously counted as `ACTIVE_MIGRATION` are reclassified `QUALIFICATION_ONLY` because the master evidence already demonstrates that the relevant production evaluator/runtime implementation exists:

* `SW431-MACRO-SEP1`: Ernst saturated seepage exchange.
* `SW431-MACRO-SEP2`: Youngs saturated seepage exchange.
* `SW431-CROP-ANNUAL`: classic annual WOFOST AMAXTB/biomass/phenology route.
* `SW431-CROP-WOF-OTHER`: IDSL=1 daylength-dependent development algebra.

This reduces the missing-production-implementation queue from 128 to 124 without declaring any of these four capabilities covered or admitted.

## Source-bounded evidence

For SWSEP=1/2, B1.11 authority is `SWAP/macrorate.f90` at the locators already hash-bound in the master ledger. The existing SWAP5 saturated-exchange component implements both selector branches. The persisted component probe passes 48 literal cases per O0/O2. The persisted real Reference/macropore runtime smoke executes both positive-conductivity branches with distinct positive exchange, committed-state isolation and zero reported whole-column mass residual. Remaining full-top, capacity, retry, restart and coupled-trajectory gates are qualification gates.

For the annual crop, B1.11 authority is `SWAP/wofost.f90`, hash-bound in the ledger. `mod_wofost_prepare_assimilation`, `mod_wofost_finalize_rates`, the two-phase crop window and `mod_fmr_wofost_crop_transaction` provide the classic route. The current-contract F-WOF38/F-WOF39 preservation replay passes O0/O2. The remaining B1.11 versus restricted classic-envelope and actual/potential ownership checks are qualification/admission work, not evidence of an absent AMAXTB evaluator.

For IDSL=1, the common finalizer explicitly computes the bounded DLC/DLO daylength reduction before anthesis and leaves generative development unreduced. Its unresolved dependency on the classic annual runtime envelope is retained. The remaining task is source-envelope qualification across daylength thresholds and anthesis.

## Closure rule

`QUALIFICATION_ONLY` remains unresolved. It retains its workunit and may be a dependency. The global `--require-closed` gate rejects either `ACTIVE_MIGRATION` or `QUALIFICATION_ONLY`. Promotion to `ADMITTED`, `SUPERSEDED`, `REJECTED` or `NOT_APPLICABLE` still requires the owning evidence.

No frost, MICRO or MIGMAC production work is taken over here.
