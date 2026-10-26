# Existing-owner macropore/Rutter/numeric heat composition

Baseline 043e92ac319d3a3b8ca40b57e995be60db91679a. HIST-INTEGRATION01.
Affected invariants: 3, 7, 13, 21, 23, 25. No new state class, process formula,
solver policy or tolerance. The existing Boesten/macropore state inherits the
optional temperature owner. Its typed restart must retain temperature exactly.

Smallest remaining dependencies: (1) runtime currently rejects numeric heat in
Rutter/Boesten/macropore layouts; (2) typed FMR restart rejects the same complete
state; (3) original native application input/dispatch and full-profile composition
remain separate, not established by a four-node interface test.

First executable closure selects the existing combined Rutter/Boesten/macropore
layout, Reference frozen conductivity, full/half stepping, numeric soil heat,
no frost/snow, no chemistry, no response drainage or root compensation. Matrix
hydraulic water is passed to the unchanged legacy numeric heat provider, as in
the historical endpoint split. No advective macropore energy law is introduced.
Thermal readiness, node identity and numeric mode must be checked explicitly.
Existing nonthermal paths retain their exact preimage behavior.

Qualification uses the existing MIGMAC10 serialized replay driver with its
rollback, smaller retry, A/B/A and typed restart assertions; add independent
bit-exact temperature comparisons, active heat and energy checks. Short controls
must reject incomplete heat configuration and unsupported modes atomically.
Check O0/O2, observer independence and same-input nonthermal preservation.
Full original Andelst, macro chemistry, multi-domain/long-duration thermal
accuracy and file restart publication remain unqualified unless separately run.

Measured qualification: checked GNU13.3 O0/O2 each execute three existing
MIGMAC10 static/unchanged/shrink modes, trace OFF/ON. Twelve native processes,
96 additional invalid heat probes, original10-envelope/competing-source
assertions, rejected state/discard/smaller retry/replay/commit and both kernel
and typed FMR restart comparisons pass. Temperature comparisons use exact bits.
Maximum independent accepted macro/matrix/column water residual8.4002e-17cm;
maximum observed last-step thermal residual1.3101e-14J/cm2. These short interface
runs do not establish thermal temporal convergence or a whole-day energy sum.
Forty uncovered and eight covered nonthermal processes retain predecessor
results; two O0/O2 five-day original112-node matrix differentials are exact.
Runtime and restart module interfaces are byte exact to the predecessor;17
transitive providers were nevertheless rebuilt and177 unchanged objects reused
per optimization. The initial no-heat-admission counterexample and failed driver
compilation remain raw evidence. Prior nutrient/481-day science is dated.
