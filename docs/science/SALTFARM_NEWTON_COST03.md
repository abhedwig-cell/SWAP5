# Why fewer SaltFarm Newton iterations give little total speedup

Research measurement; no production change or new performance admission.
The causal comparison freezes admitted sourceb4398e00a (PR1735) and its actual
Windows GNU16.2.0 compiled provider. The documentation branch starts from
canonicalcce2561eb. Newer age/output adapters are not benchmarked or relabelled
as the old source. Fixed RC3 and all scientific limitations remain unchanged.

## Result

The reduction concerns only a small part of total execution. The timed physical
Newton body takes about17% of this365day model/controller observation. Removing
about20% of that work therefore predicts a few percent total saving, not20%.
Using measured per-iteration times gives about0.096s per365days, or3.25% of
the2.960s instrumented control mean. This is an attribution estimate, not a
qualified or portable speedup guarantee.

| Measured quantity,365days | Always polish | Conditional interior |
| --- | ---: | ---: |
| Newton iterations |35048|28281|
| HeadCalc / water-step calls |9527|9527|
| Root, water-update, heat and solute calls, each |9527|9527|
| Ordinary physical iteration bodies |25521|25602|
| Padding iteration bodies |9527|2679|

All full-period counters already preserved in PR1735 remain138089→110477
iterations and38065unchanged HeadCalc calls. The short counter change agrees
with the previous reason trace:6848padding iterations disappear, while81extra
ordinary/mass-refinement iterations remain necessary under the unchanged guard.

Average control high-resolution wall intervals across the two clock blocks:

| Interval | Seconds | Fraction of total observation |
| --- | ---: | ---: |
| Whole model/controller |2.960|100%|
| Water solve, including HeadCalc |0.762|25.8%|
| Physical Newton bodies, nested within water |0.505|17.1%|
| HeadCalc setup, nested within water |0.116|3.9%|

Nested intervals must not be added. The Newton timer ends before the strict
mass guard and accepted-return administration. The complement includes other
native processes/administration, initialization/output, the Python host,
transaction kernel and waiting/scheduling; it is not all Python or all I/O.
The earlier independent RC3 profile put the water solve at about22% of total,
supporting the same order-of-magnitude explanation.

The removed padding bodies cost about14.2microseconds each, versus14.5for
ordinary bodies in the control. The evidence does not identify unusually cheap
padding as the principal cause. The fixed work and the limited total share of
Newton explain the small leverage. Original conductivity initialization remains
outside the Newton loop for SWKIMPL0. Roots, drainage, integrated bookkeeping,
transport and day exchange remain active. The number of solved steps and the
time-control policy are unchanged; equal counts alone do not prove identical
individual step lengths.

## Timing variability and limits

|365day block| Control seconds | Interior seconds | Apparent mean saving |
| --- | --- | --- | ---: |
| Uninstrumented ABBA |4.285,2.674|3.157,2.735|15.3%|
| Clock ABBA |3.269,2.655|3.045,2.869|0.18%|
| Clock BAAB |3.013,2.902|2.572,3.202|2.38%|

The first apparent15.3% is not admitted: identical control work itself changes
by1.61s between those observations, and the reverse order does not reproduce
that effect. Even the same candidate in the reverse block varies by0.63s,
far exceeding the roughly0.1s targeted saving. This does not establish which
Windows scheduling, cache, CPU-frequency, host or measurement effect caused
that variability. Per-process CPU totals are retained but have Windows clock
quantization and are not a precise additive phase decomposition.

Only one reversed clock block was selected to distinguish order effects.
These observations are consistent with the earlier full-period1.66% wall
mean difference, but cannot turn it into a precise causal or portable speedup
claim. Instrumentation preserves numerical results exactly; its complete timing
perturbation is not independently quantified because the plain/clock blocks
also drift. Timed fractions are diagnostic estimates. No tolerances, original
convergence, time-step limits, physics or output requirements are relaxed.

## Verification and recovery

Twelve365day calls took2.57–4.28seconds each, all under15second caps. Every
unrounded physical record and printed CSV matches the preserved same-policy
control. Native day109 `result.end` and `macro.bin` match their admitted
reference exactly. Both instrumented policies also pass an actual109→111cold
worker with exact physical/CSV/native equality. Water and solute balances keep
their unchanged1e-10limits and are recomputed from actual stocks and fluxes.
No new full1461day, original431, Ubuntu or broad CI campaign was needed for
this read-only investigation. Existing full/restart/rollback/isolation evidence
remains valid for untouched production. Private diagnostic workers never become
supported build bundles and no foreign checkpoint/build identity is rebound.

Evidence and read-only verification:

```powershell
python -B integration/f-ci/saltfarm-newton-cost03/verify.py
```

`SELECTION.json`, `PROVENANCE.json`, `COMMANDS.json`, `RESULT.json`,
`ANALYSIS.json`, `RESTART.json` and the indexed raw ZIP retain actual data,
source identities, counters, clocks, commands and native endpoints. Complete
local recovery, including the copied original source bytes and stdout, remains
at `C:\SWAP5-testing\saltfarm-newton-cost03`. The private reproduction recipe is
`tests/saltfarm_newton/cost_attribution.py`; its second invocation uses
`--reverse-only` to reuse compiled workers and avoid repeating the first block.

The next distinct cost question is the untimed native step administration
(including drainage, integrated bookkeeping and output) versus host/kernel
cost. Attribute that residual before selecting one bounded optimization.
Repeated-head caching, transport rewrites and compiler changes already failed
earlier discriminators and are not selected again. No further Newton stopping
change is justified by this result.
