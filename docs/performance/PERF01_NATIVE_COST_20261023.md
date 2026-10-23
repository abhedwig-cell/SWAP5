# Native application cost split, 23 October 2026

The saturated-flux repair is admitted through PR1389 at
`7ae093c5b32b4abfd10a6a37c8113ecffa2cdbb6`. The actual whole merge tree
`8485b7b391f9256973f66eabd3f629da83f2603d` equals the qualified combined
candidate exactly. The actual merge owner and all18 negative controls pass.
The existing native-weather status records this admission separately from the
historical local-only verifier result. Concurrent NUT and refined-year receipts
are preserved. Full SOL/NUT migration remains open.

## Measured work

The original admitted checked O2 executable was reused after verifying every
production input and reused artifact hash. A separate research executable adds
nested monotonic clocks in generated procedure bodies, without editing production
sources, tolerances, equations, state or defaults. Three ordinary and three
instrumented97-day runs per rainfall series produce byte-identical `budget.csv`,
`state.csv`, `endpoint.csv` and `restart.bin` against the qualified baseline.
There are no mass rejections. Gross water balance and runoff therefore remain
exactly those of the admitted paired comparison.

Instrumented median wall seconds, split into nonoverlapping categories:

| Native category | 1x | 4x |
| --- | ---: | ---: |
| HeadCalc, including constitutive and Newton work |0.778|0.760|
| Physical trial provider, adapter and state work outside HeadCalc |0.297|0.267|
| Transaction controller and state work outside physical trials |0.037|0.033|
| Chemistry and joint interval orchestration outside transactions |0.060|0.052|
| Native setup, output and launch residual |0.024|0.016|
| Instrumented total |1.196|1.129|

HeadCalc takes about65 to67% and its surrounding trial work about24 to25%.
Direct controller work is only about3%. Separately timed rejected attempts
consume0.968/0.954s, about81/85% of the instrumented process total. This rejected
time overlaps the rows above; it must not be added to them.

| Work counter | 1x | 4x |
| --- | ---: | ---: |
| Accepted transactions |4,978|3,577|
| Accepted half-substeps |9,956|7,154|
| Attempted transactions |37,371|32,702|
| Temporal rejections |31,041|27,528|
| Solver rejections |1,352|1,597|
| Actual HeadCalc invocations |109,826|95,709|
| All nonlinear iterations |475,366|448,141|
| Nonlinear iterations on the accepted half trajectory |35,142|25,640|

Work outside the accepted half trajectory includes both rejected attempts and
the full-step comparison required by the current controller. The latter is
useful assessment work, not automatically avoidable waste. The original
application logs979 iteration hits and3,223/3,100 nonlinear iterations. Original
hits and current accepted half-substeps have different semantics; this is not
an accuracy-matched comparison.

## Front end and output

An additional three serial alternating original/current pairs per rainfall
series retain the ordinary complete project route. Current full-process medians
are1.282/1.277s in this sample. Paired outer cost beyond the wrapper's native
measurement is0.151/0.152s: Python startup, native input preparation and publication.
That measurement is not pure disk I/O. The native setup/output/launch residual
above is also an upper envelope rather than an isolated output timer.

Ordinary native-only medians in the separate profiling sample are1.212/1.023s.
Scheduler/load variation is visible: instrumentation is slightly faster in one
sample and slower in the other. Do not subtract independently sampled medians
to estimate timer overhead or interpret the latest1x/4x timing difference as a
physical change. Repeated work counters and all physical bytes are exact.
The earlier1.237/1.088s observations remain valid for their recorded sample.

## Next numerical target

`mod_canonical_interval_runtime` starts each new transaction at the remaining
interval endpoint unless an accepted-step proposal is active.
`retain_accepted_step_proposal` defaults false here; the native crop and soil
evaporation application explicitly rejects its activation. Thus a successful
small step does not prevent the next transaction from retrying a much larger
remaining interval and halving it again. The measured rejection counts and
timed rejected work make this the first target, ahead of file-output tuning.

Qualifying retained proposals for this real crop/soil evaporation combination
requires its owning numerical compatibility contract, actual water/runoff and
accepted-state checks, and fresh restart continuation. This investigation does
not bypass that exclusion or change policy. Reducing rejected work is promising;
no speedup or equivalent-accuracy result has yet been established for that change.

Machine-readable observations and a manifest-bound raw capsule are in
`benchmarks/performance/PERF01_NATIVE_COST_20261023_RESULT.json`. They retain
generated sources, compile/run streams, ordinary/profile outputs, complete paired
application outputs and development failures. No new1e-6 run, RossFast extension,
highest-low-air or broad F-CI was selected. Affected architecture invariants
2,5,7,13,23,26 remain satisfied: instrumentation is external research work and
changes no production or acceptance semantics.
