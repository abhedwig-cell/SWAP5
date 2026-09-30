# F-PE-NLGLOB14Z25 preregistration — internal chatter execution-burden attribution

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

Parent authority:

- Z22: repeated finite internal bidirectional chatter is real and transaction-clean;
- Z23: settled publication can coalesce event bursts without changing internal physical ownership;
- Z24: moving-interface ownership is not part of the current external groundwater coupling surface.

## Purpose

Determine what execution burden can be attributed to the observed chatter from existing qualified evidence, without inventing a no-chatter counterfactual physical trajectory.

Separate two questions:

1. does chatter cause extra timestep retries, substep insertion or rejected accepted-state intervals;
2. can current evidence quantify nonlinear/operation cost within those nominal intervals.

## Frozen evidence

Use only the qualified Z22/Z23 evidence for the two fine O05 fixtures:

- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 6.25e-5 d.

The frozen event evidence is:

`tests/fpe/data/f_pe_nlglob14z23_z22_event_evidence.json`.

Do not rerun or alter the physical trajectory in this workunit.

## Frozen diagnostics

Per fixture record:

- nominal dt;
- observation horizon;
- number of ownership-change intervals;
- number and length of consecutive chatter bursts;
- total chatter-span intervals;
- chatter-span fraction of the observed nominal interval count;
- presence of solve failure;
- presence of rollback leakage;
- presence of explicit retry/substep evidence;
- whether any ownership change itself inserts an extra time interval;
- whether per-interval Newton iteration counts or operation counts are present in frozen evidence.

## Frozen classifications

### CHATTER_ON_NOMINAL_ACCEPTED_INTERVALS_ONLY

Require:

- ownership changes occur at integer nominal offsets;
- physical time increments remain exactly dt;
- no solve failure is associated with the event sequence;
- no rollback leakage is present;
- no explicit retry/substep event is present in the frozen evidence;
- chatter does not insert additional physical intervals.

### CHATTER_CAUSES_RETRY_OR_SUBSTEP_BURDEN

Any frozen evidence that ownership chatter itself triggers retries, step halving, inserted substeps or rejected time-advancing states.

### OPERATION_COST_QUANTIFIED

Only if the frozen evidence contains sufficient per-interval solver iteration/operation data to attribute nonlinear work to chatter intervals versus surrounding stable intervals.

### OPERATION_COST_UNRESOLVED

If no such per-interval work counters or timings exist.

## Frozen aggregate interpretation

If both fixtures classify `CHATTER_ON_NOMINAL_ACCEPTED_INTERVALS_ONLY` and operation cost is unresolved:

`QUALIFIED_Z25_NO_TIMESTEP_RETRY_BURDEN_OPERATION_COST_UNRESOLVED`.

If chatter causes retry/substep burden:

`NLGLOB14Z25_CHATTER_EXECUTION_BURDEN_CONFIRMED`.

If operation cost is directly quantified without extra retries:

`QUALIFIED_Z25_CHATTER_OPERATION_COST_CHARACTERIZED`.

## Interpretation boundary

A positive no-retry result does not prove zero runtime cost.

Ownership changes alter the internal split and may change nonlinear-system size or iteration count on subsequent intervals. That requires explicit instrumentation.

Do not estimate wall-clock cost from event counts alone.

## Stop rules

Do not:

- create a no-chatter physical counterfactual;
- suppress ownership changes;
- alter dt or forcing;
- infer Newton iterations from missing data;
- call a small event fraction a runtime fraction;
- change production code.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z25

BASELINE: `5bff305ee1c735a479462c5e29426be5bdfbcb26`

BRANCH: `research/f-pe-nlglob14z25-chatter-burden`

NEXT SAFE STEP: derive interval/retry burden from the frozen Z22 event evidence and classify operation-cost observability separately.

## Production boundary

Research/evidence attribution only. No production source/default change.
