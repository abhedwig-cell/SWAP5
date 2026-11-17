# Day215 groundwater discrepancy: isolated storm-time discretization

PR1697 is merged at canonicalfd162a1ea22c41e798a431f39957aaff9c173e46. Its actual
merge parents/tree and current admission consumer were verified in a clean
detached checkout; eleven existing negative methods and fifteen new corruption
variants pass. The merge receipt is on pulse branch90a8a1c68. This separate
investigation changes no production code or accepted default.

## Cause and first material divergence

After the short-irrigation repair, the selected water-surface-history case
retains a maximum groundwater difference1.399492693221cm from original431 on
day215,2002-08-03. The difference is about-0.000505cm at end211 and remains
tiny through the earlier day200 runon pulse. Day212,2002-07-31, has50.2mm rain.
The nominal GWL differences over212/213/214/215 are respectively
+0.002017/-0.150019/-1.109744/-1.399493cm.

The divergence starts in the storm's pressure/moisture profile before it becomes
large in groundwater level. At end212 the nominal maximum head discrepancy is
9.06567cm at node16 and maximum theta discrepancy0.0113431. These differences
propagate into the groundwater region on subsequent days. There is no runoff
or drainage discrepancy in this window. Root uptake differs0.001574cm on212;
that observation is retained, not silently reset.

Original431 accepts38 steps during storm day212, beginning at0.013333day;
SWAP5 accepts25 steps of approximately0.04day. This repeats the earlier causal
pattern: improved nonlinear convergence can permit a temporally coarse wetting
trajectory. Conservation/convergence tests are not temporal-accuracy tests.
The existing original groundwater calculation is unchanged; the divergence is
already present in the actual hydraulic profile, not just in GWL reporting.

## Distinguishing intervention

Both models start from their own original state. An explicit diagnostic DTMAX
cap begins only at start212; every day0-through-day211 CSV row is EXACT to the
respective immutable complete reference. SWAP5's first211 physical daily
records are also exact. No state is substituted between models and no native
checkpoint is rebound. The initial small difference between models is retained.

The only source additions are accepted-step/profile output and the explicit
four-day time cap. Original equations, input forcing, event clocks, convergence
and water tolerances remain unchanged. Output-only nominal controls reproduce
all216 CSV rows of the original complete prefixes exactly. The driver stops at
day215; it does not repeat a complete1096-day trajectory.

| Four-day time cap | Original431 GWL215,cm | SWAP5 GWL215,cm | Difference,cm |
|---|---:|---:|---:|
| Original nominal DTMAX0.04day | -126.165640806702 | -127.565133499923 | -1.399492693221 |
| 0.004day from start212 | -126.171900322889 | -126.172679152974 | -0.000778830085 |
| 0.0004day from start212 | -126.192369623321 | -126.193365413066 | -0.000995789745 |

With0.004day both take250 steps on212; with0.0004day both take2500. At end212,
the maximum head difference falls to about0.0011cm and theta difference to
about1.23e-6. At end215 with the finer cap, maximum head difference is
0.00099579cm and theta difference1.42620e-6. An independent O0 SWAP5 execution
at that cap has exactly the same four daily GWL outputs as O2 and preserves its
own first211 physical records exactly.

Changing only SWAP5 while retaining the unchanged nominal original reference
also removes most of the discrepancy: the0.004day SWAP5 result differs from
nominal431 by-0.00703835cm; the finer result differs by-0.02772461cm. The original
reference itself moves by about0.02673cm under refinement. Therefore close
agreement on a common refined grid must not be called an independently
qualified reference limit. No Richardson order or zero remaining error is
claimed. The residual around0.001cm is consistent in scale with the retained
prehistory difference; its exact attribution is not proven here.

## Decision and scope

The1.40cm discrepancy is explained as sensitivity to the storm/wetting temporal
grid. A separate physical-formula or GWL-reporting repair is not justified by
these observations. The production short-irrigation policy remains as admitted;
these four-day caps are diagnostic, not a silently activated rainfall policy.

Every SWAP5 day remains accepted under its unchanged1e-10cm independent/kernel
mass limits. The largest observed residual in these diagnostics is about
1.477e-13cm. No tolerance, historical failure or scientific criterion is relaxed.
This investigation is water-only, source-bound and Windows O0/O2; it does not
add chemical, whole-period or portable scientific qualification. Whole science
remains NOT_QUALIFIED, including the original nominal reference comparison.

Seven short model executions were used: three nominal/refined pairs and one
O0 confirmation. Each model execution took less than2.3seconds; only their last
four days were refined. Compilation is recorded separately in exact commands.

The next implementation target is a bounded local temporal-accuracy policy for
rapid rain-driven wetting, with event/soil-state activation and measured costs.
It must avoid globally shrinking DTMAX or using the old solver's convergence
failures as an accuracy controller. These diagnostics provide a causal target
for its short preflight, not an all-project parameter calibration or permission
to change scientific thresholds.

## Evidence and reproduction

Execution sources:d7a495b9a for the O2/original pairs,7e4d0dd13 for O0 confirmation.
Both have the exact canonical production app/src/reference/tools surface.
The composed production bundle is validated before diagnostic compilation;
private executables retain distinct source/binary hashes and publish no native
state. RESULT.json records source/provider, commands, actual timings, budgets
and all four daily endpoints. PROFILE_ASSESSMENT.json and O0_CHECK.json retain
the field comparison and independent confirmation. RAW.zip/RAW.json bind every
raw input, generated source, full accepted-step profile, output and metadata.
Executables/compiler objects/modules are excluded from the compact archive;
their identities and original provider manifest are retained.

Use the source/compiler-validated original provider and the exact composed
bundle/input/full-reference dependencies recorded by PR1697. Both scripts
require fresh output directories; place the MSYS2 UCRT64 binaries on PATH:

```powershell
python -B tests/day215_cause/run.py
python -B tests/day215_cause/check_o0.py
```

The requested merge and bounded causal follow-up are complete. A production
rain/wetting policy would be a new implementation/qualification block, not a
reclassification of these diagnostic results.
