# External macropore accepted-water trace

Owner HIST-INTEGRATION01; baseline2d21939f285615818ba94352187d40abe2466d8e.
Invariants7/13: detached candidate, complete mass accounting and atomic rejection.

Additive read-only observation fields record the existing converged macropore
requested/accepted/returned top amounts, pond donor split, direct external
accepted input, and per-domain/per-cell rapid external outflow rate. Units are
cm per column area for amounts and cm/day for rates. Accepted vertical top face
is the accepted total amount divided by substep duration. Rapid outflow is an
external sink, never a fictitious intercell exchange. Domain storage satisfies
dW/dt = incoming face - outgoing face - transfer to matrix - rapid outflow.
The pond donor is internal and subtracted once from accepted direct external
input. Requested equals accepted plus returned; pond requested equals pond
accepted plus pond returned. Every scalar and array must be finite, nonnegative
where applicable, shape-compatible and consistent. Matrix storage uses actual
dz times the existing matrix area fraction.

The original producer supplies all receipts. No inference from a balancing
residual, pool reset, clipping, physical equation, accepted state, restart layout
or numerical tolerance change is allowed. TraceON/OFF must retain the original
physical candidate and temporal metric. Rutter/Boesten/macropore implicitCauchy3
uses its already admitted composed metric, not the plain-Boesten trace metric.

Initial supported scope: uncovered top-node1 macropores with existing direct
atmospheric/pond donor, capacity return and rapid drainage, including existing
Rutter/Boesten/Cauchy3 compositions. Covering transfers between different matrix
and macro cells remain rejected. Salt, heat, snow and new native full-Andelst
activation are not admitted by this observation repair. Existing chemical
external-source guards remain authoritative.

Qualification selection: real original trial/replay drivers with traceON/OFF,
static/shrinking variants, positive top/return/pond/rapid cases, independent
per-domain cell/whole-column budgets, committed-state rejection and existing
fresh serialized restart. Checked O0/O2; rebuild changed modules and their actual
transitive consumers, reusing other objects only with exact source/compiler/flags
and artifact binding. Expected below300s; retain failed rounds and timings.
Current owner/source controls and FSI35 preserve the changed shared-runtime
boundary. No unrelated fullFCI, highest low-air, RossFast or1e-6 run is selected.

Qualification note: the whole-column independent check uses the actual declared
matrix surface potential, accepted macro top amount, explicit capacity return
and rapid sink, not an inferred atmospheric allocation. Existing converged
rain diagnostics retain their prior non-certifying meaning. No new gross
atmospheric source-partition or full original-project equivalence is claimed.
The pond surface check corrects the original producer's requested pond transfer
and capacity return; numerical thresholds and physical endpoints stay exact.
