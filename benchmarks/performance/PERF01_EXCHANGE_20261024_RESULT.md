# PERF01 same-state runoff and interval investigation,24 October2026

Research evidence only. No production source, default, guard or admission changes.
Canonical d04a8c3cca1ac9246e66dc913ba588472a5fb78c is reconciled. Fresh checked
GNU13.3 O0/O2 builds include the original194 physical providers and153 original
input providers. All197 original physical-build inputs match the earlier
research surface; separate NUT/FCT canonical changes do not touch that closure.

## What the discriminator establishes

All three routes start from the SAME actual day145 disk state and execute the
original4x detailed rainfall through day153. Restoring dry-head control, actual
incumbent Darcy-exchange assessment, or the complete incumbent assessment does
not remove the day152 runoff shift: maximum difference remains approximately
0.6358mm. Thus omission of those controls does not explain this local event.

Numerically partitioning each original constant-rain interval changes BOTH
trajectories. Original event endpoints and rates are preserved. Observed daily
rain-integral differences remain below1e-9cm.

| Maximum research interval,day | Ordinary day152 runoff,mm | Guarded flux day152 runoff,mm |
| --- | ---: | ---: |
| Uncapped |7.582651211|8.218462314|
|0.04|7.990746537|7.994766172|
|0.02|7.991468146|7.994689168|
|0.01|7.993475128|7.994689153|

The ordinary trajectory is itself interval-sensitive. Its uncapped value cannot
be treated as exact truth when interpreting the former0.636mm difference.
No asymptotic accuracy order or fully converged value is established. Other
days still differ: the largest8-day head/flux discrepancy at0.01day is0.0149553mm,
so the existing strict0.01mm screen remains FAIL.

## Full-period result and deployment boundary

The0.01day interval policy is NOT selected for production:

- 1x ordinary and guarded flux reject day66 after65 published days.
- 4x ordinary rejects day4 after3 published days.
- 4x guarded flux completes481days; largest water residual1.416e-14cm. Its27.07s
  native time is an individual observation during other work, not a performance
  estimate. It is much slower than the prior3.40s unguarded research observation.

The full completed4x trajectory has an actual byte-exact day240 restart: final
state,endpoint,restart and all241 continued budget rows match. The selected
8-day incumbent and0.01day head/flux outputs are byte-identical across O0/O2.
The failed1x/4x ordinary executions are independently reproduced with added
HeadCalc observations; all previously published daily bytes AND each rejected
partial-candidate binary remain exact. Instrumentation does not repair them.

The failing1x request is day66,[65.104000000003,65.113000000003],rain2.6111111111cm/day.
Its final origin has maximum head about-6.98e-18cm. The4x request is
day4,[3.760000000001,3.770000000001],rain0; its final origin maximum is about
+1.78e-10cm. Repeated solver retries shrink to approximately1e-13/1e-12day
without convergence; no mass rejections occur. This localizes the next diagnostic
to near-zero pressure-head transitions and retry behavior. It does not yet prove
which solver equation or switch is defective or authorize clipping physical state.

The first naive research partition left artificial1e-13day final tails; those
captures are retained separately as driver failures. The balanced partition fixes
that experimental-driver issue. The later full failures above involve ordinary
positive-duration requested intervals and are a different observation.

## Reproduction and integration

`PERF01_EXCHANGE_20261024_EVIDENCE.tar.xz` contains a verified per-member manifest,
all fresh build reports and generated sources, exact inputs/day145 restart,
complete and partial raw outputs, original failed partitions, O0/O2 identity,
full4x restart and observer-exact failure captures. The adjacent JSON owns hashes
and measurements. Earlier endpoint/refinement capsules remain immutable.

Build a checked native bundle with `tools/solute/build_project.py` at O0/O2.
Generate the original research endpoint build with `screen_perf01_geometry.py`,
`PERF01_RESEARCH_ROUTE=historical`, `PERF01_BOESTEN_ENDPOINT=1`,
`PERF01_BUILD_ONLY=1`, and `PERF01_SCREEN_BUNDLE` pointing at that fresh bundle.
The new `study_perf01_exchange_guard.py`, `study_perf01_segment_refinement.py`
and `observe_perf01_segment_failure.py` expose explicit bundle/build/input/output
arguments; frozen example commands and exact inputs are inside the capsule.

Next safe implementation work: reproduce the two saved near-zero-head failure
states through the actual Richards provider and locate the failing equation or
boundary switch before designing a source repair. Retain the original working
uncapped research route. Neither an unqualified cap nor a smaller solver tolerance
is a production fix. Plain-Boesten endpoint semantics and output-amount policy
still require their owning production qualification. Positive chemistry remains
excluded. No1e-6/RossFast expansion/heavy low-air/full moving F-CI was selected.
