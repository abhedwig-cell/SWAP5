# Wet uniform-head native failure isolated to shared water execution

Twelve actual native O0/O2 diagnostics compare frozen, Picard and continuous-MvG/
Picard policies at identical wet forcing and either uniform or original sloping
initial heads. All six uniform-head cases reject in the water owner before
chemical execution. All six sloping-head cases complete0.4days. Their independent
maximum water/chemical residuals are1.996e-14cm/1.097e-13mg/cm2. O0/O2 successful
profiles and all diagnostic stdout are byte-identical.

A freshly compiled original-production reactive-step control reproduces the
uniform/frozen failure exactly: water status2, chemical status1 (not executed),
86 attempts,37 solver and46 temporal rejections, completed chemistry0. Its stdout
is byte-identical to the FCT control. This excludes an FCT-specific explanation
for this reproduced failure. It does not distinguish the final hydraulic trial,
accepted private water trajectory, temporal estimator or surface transition.
No full root-cause claim or production repair is justified yet.

All raw successes, failures, native inputs, process commands/streams, compiler
streams, generated reference sources and physical source snapshots are sealed.
The missing old compiler route is retained as failed build metadata; recovered
GNU13.3.0 compiles201providers and153 original readers afresh. The reference
builder retains an unused FCT import but calls the original production reactive
step. The tested source dependency hashes remain exact after canonical receipt
d04a8c3c. No physical input, tolerance or guard was relaxed to claim success.

Next: instrument the original water owner to identify last committed private
time, trial duration, head/pond state and rejection reason near the failure.
Keep positive pond and uniform head unchanged. Avoid inferring repair from a
different initial profile or dry surface. Production defaults remain unchanged.
