# Research extension to120cm geometry, Boesten and Picard

Generated research executables retain original production physical equations,
mass/transaction gates and numerical budgets. The private eligibility scope is
extended for120cm profiles with8/24 cells, prescribed bottom and zero tracer.
Boesten uses its actual forcing and derived state; SPEV andSAEV retain their
existing0.001cm temporal bounds. The public backend module is byte-exact to
its production counterpart. Production sources and admission guards are unchanged.

Four plain geometry cases and four Boesten cases complete97days at O2 (1x/4x
rain). Four combined Picard+Boesten cases also pass the declared runoff,storage
anduptake screening criteria:

| Cells | Rain | Head native,s | Flux native,s |
| --- | --- | ---: | ---: |
|8|1x|2.925|0.246|
|8|4x|2.361|0.208|
|24|1x|15.064|0.758|
|24|4x|12.132|0.664|

These are individual native observations, not paired benchmark medians. Maximum
daily runoff/storage differences are0.0069mm; water residuals are below3.4e-14cm.
Total evaporation and uptake are numerically equal. Soil/pond evaporation
allocation differs by up to0.175mm/day in the Boesten screens; these separate
components are not independently qualified. The full O0 eight-cell1x/4x
head/flux outputs are byte-exact to O2, including native restart states. All four
O2 combined day48 separate-process continuations reproduce the full physical
endpoint/restart bytes and remaining daily budget exactly.

Initial interface checking failed solely on the compiler module's source-filename
header; subsequent generation retains the original filename and passes the
unchanged exact-module check. Initial Boesten attempts reject before any solve:
plain and Boesten routes have different state/forcing layouts. The corrected
research adapter includes actual Boesten state/history and forcing. All rejected
captures are retained separately, never counted as successful physical runs.

This is research evidence, not production qualification. Continuous-MvG Picard,
seasonal/detailed historical forcing, implicit or positive solute transport,
the complete481-day combined case and current shared-owner preservation remain
open before a production expansion. No new1e-6 trial, RossFast extension or
heavy low-air test is selected. The JSON and648-member capsule contain the
executed sources, inputs, outcomes, failed attempts and exact restart checks.

## Later execution-route correction,24 October2026

The Picard subset triggered97 zero-work preflight rejections per arm and retried
with ordinary step policy. Its bounded physical evidence remains valid, but it
does not qualify active Picard retained proposals. See
`PERF01_HISTORICAL_20261024_RESULT.md` for the full481-day failed daily-accuracy
comparison and exact route diagnosis. Original evidence capsule is unchanged.
