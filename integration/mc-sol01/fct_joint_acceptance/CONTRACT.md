# MC-SOL01 research joint acceptance

Baseline: `57e1b3f2635559df0db0350a96f0e06b2e3b9cc7`.
This isolated research successor composes the unchanged real serialized water
backend with the admitted research FCT trace consumer. No production dispatch,
default, solver, process formula or shared interface changes.

Water and chemical clocks and carrier arrays must match exactly at entry.
Water is trialled privately; its accepted substep trace supplies all hydrological
chemical forcing. Chemical constitutive inputs are explicit (one base model or
one model per water substep). Only after the entire chemical batch passes may
the kernel publish water, followed by the already validated chemical candidate.
Any earlier rejection discards the candidate and leaves both committed states
unchanged. This serial single-owner wrapper does not claim concurrent commit.
Allocation/process crashes across the two assignments are outside this proof;
it is not a crash-consistent joint persistence protocol.

Qualification selection: real Reference O0/O2, checked builds, 40/80 cells,
0.8/1.2 initial-conductivity infiltration, Freundlich 0.5/1/2, four 0.1-day
windows. Late unsupported chemistry after a valid prefix, water incomplete-trial
rejection, exact retry, clock/carrier mismatch, model-count mismatch, and
continuation from the public opaque kernel persistence snapshot plus chemical
value checkpoint. Compare physical state, temporal history and provenance.
Expected compile cost 100 seconds; individual process ceiling 180 seconds.
No disk encoding or fresh-process native restart claim. No dispersion, decay,
root/drainage sinks, native-year, RossFast, highest-low-air or full F-CI selection:
isolated research does not alter these production dependency surfaces.
The existing exact-empty-pond option is selected on both FCT/low-order paths
by the exact predecessor two-keyword source generator, without formula changes.
Conservation and positivity assertions are not relaxed.
