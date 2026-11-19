# SaltFarm timestep administration and CSV work

Research result: **no production speedup admitted**. The measured fixed native
step administration is small. A CSV append candidate removes repeated whole-line
allocation/copying and passes the full physical/restart checks, but its total
speed benefit is not distinguishable from unchanged-control drift. It is rejected.
All production source, tolerances and fixed RC3 remain unchanged.

## Scope and discriminator

Reuse the [prior Newton attribution](SALTFARM_NEWTON_COST03.md) and
[earlier rejected performance probes](SALTFARM_RC3_COST02.md). The experiment
freezes admitted source `b4398e00ae978c82f0cdee3d72ff79708a869762`, its original
Windows GNU16.2.0 O2 provider/build and original SaltFarm input. The research
branch starts at canonical `cce2561eb87e992f671d97a35baef84ddb8d91e0`.
Newer canonical adapters are not relabelled as that old build. Private diagnostic
workers are never supported bundles; their private checkpoint bindings are explicit.
No current-canonical candidate admission or portable performance claim is made.

Integral and SoilWaterStateVar already operate only on the 195 active nodes.
The suspected unnecessary traversal of all 5000 reserved nodes is absent there.
Original drainage uses DRAMET3, two levels and vertical distribution; it depends
on the evolving groundwater state and is retained on every step.

Two365day high-resolution clock runs retain9527 water steps and28281 Newton
iterations. Mean observed intervals:

| Interval | Seconds per365days |
| --- | ---: |
| Integral reset |0.00605|
| Weather processing |0.00567|
| Time preparation |0.00069|
| Bottom boundary |0.01159|
| Drainage |0.09591|
| Integral update |0.04398|
| Time advance |0.00590|
| Output block |0.70580|

The seven administration intervals total about0.170s:17.8microseconds per
water step,3.6% of measured model/controller wall. These are instrumented wall
intervals, without an independently quantified clock-overhead correction.
Output-block entry is counted9527times; this is **not** proof of9527CSV writes.
The selected PERIOD1 input produces365daily CSV rows plus its initial row.
The output work is therefore principally daily cost, not fixed physical-step cost.
Do not attribute the remaining unmeasured wall to Python alone: initialization,
other native work, kernel, IPC and waits are also outside these intervals.
No previous rejected cache, relay, compiler or convergence experiment is repeated.

## One candidate and the decision

The private candidate changes only ASCII CSV assembly. Instead of reallocating
and copying the growing row for every field, an invocation-local buffer reserves
30characters per requested field and appends each existing formatted field by
substring. The existing30character field and19character date bound that capacity.
Formatting, numeric values, ordering, output fields and physical calculations stay
literal. No shared cache or restart state is introduced. Only the dynamic CSV
routine changes; initialization/header/binary paths are preserved.

Both365day candidate profiles have exact physical/CSV/native equality. Observed
output-block intervals are0.657/0.643s versus0.674/0.738s in the initial controls;
these separate blocks alone are insufficient to claim a gain.

The decisive uninstrumented full1461day ABBA controls, on the same laptop:

| Order | Worker | Seconds |
| --- | --- | ---: |
|1|Unchanged control|15.3364|
|2|CSV candidate|15.5957|
|3|CSV candidate|15.5921|
|4|Unchanged control|16.7373|

The candidate mean is2.76% lower than the control mean, while unchanged controls
drift9.13%. The first candidate is slower than the first control. A stable whole
runtime benefit is not established. Do not promote this as a2.76% speedup or
continue a large benchmark campaign to seek a favourable result. The candidate
is rejected and no production patch is retained.

## Full verification and recovery

All four complete periods match every unrounded physical day, printed CSV row
and eight native endpoints (109,111,365,367,453,455,1460,1461) to the admitted
same-policy golden. Five actual candidate cold workers pass109→111,365→367,
453→455,1460→1461and109→1461, each with exact physical/CSV/result.end/macro.bin
continuation equality. Two profile cold workers109→111also pass.

Unchanged water/solute limits remain1e-10cm and1e-10mg/cm2. Full maximum independent
water residual is5.1061e-11cm; solute7.6555e-12mg/cm2. The cumulative water residual
remains2.0295e-8cm. No heat/physical qualification or historical scientific FAIL
is reclassified by these performance tests. Untouched production retains its
prior O0/O2/Ubuntu qualification; the rejected private CSV candidate is WindowsO2
only and does not receive that inherited qualification.

The selected campaign has15model calls: four365day profiles, two short profile
cold workers, four complete controls and five cold workers. Prefixes use15second
caps; complete/continuation calls25second caps. Every call completes within cap.
No new original431 run is needed for an output-only candidate that is exact to
the existing admitted trajectory and rejected on performance.

`integration/f-ci/saltfarm-step-cost04` preserves results, phase clocks,
independently recomputable balances, inputs, generated sources, compiler/link
commands, build identities and native origins in an indexed/sealed raw archive.
Run the read-only verifier:

```powershell
python -B integration/f-ci/saltfarm-step-cost04/verify.py
```

Private recipes are `tests/saltfarm_newton/step_cost.py`, `csv_probe.py` and
`csv_full_probe.py`; they use the explicitly frozen prior source and provider,
without rebinding foreign builds. Local recovery directories are
`C:\SWAP5-testing\saltfarm-step-cost04`, `saltfarm-step-cost04-csv` and
`saltfarm-step-cost04-full`. The source/provider dependencies remain at the
paths recorded by PROVENANCE/STATUS and the recipes.

Functional coverage does not expand; four full periods and seven cold workers
support rejection of this specific optimization. Development yield is a bounded
cost explanation and a tested decision, not an admitted runtime improvement.
No further step/CSV micro-optimization is selected. Any next performance work
must first identify a different dominant cost and retain the complete mass,
rollback, external and restart contracts; repeated failed cache/relay/compiler
or looser convergence approaches are not a next step.
