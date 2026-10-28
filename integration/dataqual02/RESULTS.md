# DATAQUAL02 measured surface-demand correction

Canonically integrated by PR1461, merge0e3cd4889c36ad101b0bc19072036e3a4471f99e.
The complete merge tree equals qualifiedc3d43144f8a255dff1b6c83945edf1ecc0ff225c;
source/raw owner verification passes on the actual merge. Baselinead620538.
This is an explicit default-off experimental source-mapping correction. Production
and comparison keep their old mapping. No physical equation, numerical tolerance,
transaction or restart format changes. Only the two positive-demand assignments
identified in PR1457 are reused; its other source and long-run claims are excluded.

## Actual execution

Twenty scenario executions (including build/reporting repeats):14 physical passes,
4 intended input/mode rejections and2 timeouts. The14-case main O2 batch contains
10 physical completions,3 intended rejections and1 censored continuation. Four
one-day forcing/initial-state configurations were each run with demand OFF/ON.
A combined active empirical-root oxygen case also completes. A separate corrected
source-event2.495 checkpoint completes, followed by a15s censored local-window
probe. These are executions of a small historical configuration family, not20
independent historical projects. The second counted batch timeout is deliberately
limited to0.1s to verify censored-result reporting, not a second numerical-failure
diagnosis. A fresh extracted-binary/checkpoint5s replay reproduces the first three
full/half diagnostic records exactly and leaves the input restart unchanged; it
remains censored and does not qualify the next source window.

Checked GNU13.3 O0/O2 use the existing hash-verified unchanged194-provider physical
build. Corrected original2day state, temperature, budget, progress, cost, groundwater
and physical restart payload are exact between optimizations. The unselected
variant's complete2day physical files/payload remain exact to DATAQUAL01.
Corrected full versus day1→day2 endpoint files and complete restart.bin are exact.
Six direct native wrong-mode/unknown-variant/corrupt/foreign-restart controls reject
before output publication, preserving input bytes. Python mode guards are checked
separately. Collector diagnostics now preserve argparse errors, explicitly label
timeouts, and report unavailable fluxes as null when no completed budget row exists.

## Physical result and reference limits

| Quantity | Literal mapping | Corrected source mapping |
| --- | ---: | ---: |
| Day1 soil evaporation, cm |0|0.04197689727112184|
| Day2 soil evaporation, cm |0|0.014256421201912298|
| Day1 GWL minus rounded431, cm |+0.17825123049641434|+0.04749032723505309|
| Day2 GWL minus rounded431, cm |+0.8925642536169391|+0.06042660032071012|
| Returned-window nonlinear iterations, days1–2 |62112|49331|

The original positive first-day potential is0.041976897271121826cm; actual demand
matches within rounding. Boesten SPEV/SAEV are positive in the original endpoint.
That history oracle is deliberately limited to original input: altered rainfall
can legitimately reset drying history, so positive end-history is not required
for every rain variant. All demand-ON paired cases have positive actual soil loss.
Successful batch independent water certificates stay below1.17e-14cm; the separate
2.495 checkpoint has maximum independent certificate3.89e-14cm and signed partial-
day residual-7.68e-14cm. No negative-water clamp or relaxed budget was introduced.

The corrected day2 GWL error is substantially smaller, but nonzero. The reference
is frozen rounded4.3.1 output, not an independent hard-mass certificate. Drainage
comparison remains descriptive/provisional. Lower iteration count follows changed
physical forcing; it is NOT evidence of a generic solver speedup. Timings include
concurrent probes and are not a controlled portable performance comparison.

## Remaining numerical blocker

Corrected day2→day3 still times out after30s, with complete source windows through
2.495:2314 returned-window attempts,1173 temporal rejections,28014 nonlinear
iterations and zero recorded solver/mass rejections. In-flight work is not counted.
An explicit complete-event run retained the exact corrected2.495 file in17.09s,
using its own day2 origin. Its matched executable and a direct replay command are
in the evidence capsule and `RECOVERY.json`; no old-source foreign restart is used.

The following2.495→2.514 local window remains censored at15s. Diagnostics show
in-flight progress around2.50324, with step widths near1e-6days. One initial trial
has a full/half pressure discrepancy1.3176cm at duration0.0095days while the recorded
macro topology is equal. That is a transient/feedback cost signal, not proof of a
specific constitutive or boundary defect. In-flight trial progress is NOT a
completed/committed source window or a recoverable checkpoint.

The omitted demand was therefore a real physical mapping error, but not the sole
cause of stagnation. A speculative tolerance change or another outer-iteration
microrepair is not justified by this experiment. The next numerical block should
use the preserved corrected2.495 state and the independently reviewed PR1457
hydraulic residual/Jacobian work, without silently inheriting its altered physics.

## Reproduce and continue

Build the existing native bundle, then run `tools/solute/run_dataqual_batch.py`
with `integration/dataqual02/scenarios.json`. The explicit option is
`--source-surface-demand --mode experimental`; both native and Python gates enforce
this. All selected input derivatives, source fingerprints, budget/progress/cost,
reference deltas and rejected/censored outputs are retained. `summary.csv` is the
machine-readable scenario table; `STATUS.json` owns the evidence-part order/hash.

Priority next steps: (1) diagnose the2.495 hydraulic transient from the retained
file; (2) reconcile PR1457's residual/Jacobian and physical variants separately;
(3) extend selected corrected-source histories and reference comparison; (4) make
in-flight work recoverable/observable; (5) consider production promotion only as
an explicit separate decision. Full historical closure and chemistry/N stay open.
