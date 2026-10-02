# PPA-WU05-C3A-PERF02 preregistration: oxygen eligibility gate

Date: 2026-10-02
Baseline canonical: a89990169fb8429a0fd143df9e3d28b9a35d28b8

## Hypothesis

A material fraction of admitted Bartholomeus evaluations can be skipped because cheap trial-start state variables already imply that the full REFERENCE evaluation will return no oxygen reduction.

An older pre-SWAP5 investigation reportedly found a substantial avoidable-call fraction, informally remembered as roughly 20%. That number is not treated as evidence and must be reconstructed/falsified on the current implementation.

## Separation from PERF01/E2E01

PERF01 reduced cost per necessary call by reusing trapezoid refinement work. E2E01 measures remaining ON versus OFF production-application cost. Neither line is discarded.

PERF02 tests call elimination only. It must not hide remaining per-call overhead. Results must report both:
1. fraction of calls safely skipped;
2. residual cost of calls that remain eligible.

## Safety criterion

The gate may skip a full Bartholomeus evaluation only when a cheap sufficient condition proves that every rooted oxygen factor produced by the admitted REFERENCE route is 1 within the existing exact/preservation semantics.

False-positive skip is a falsification: if the gate says SKIP while the full Reference route produces any material reduction, the candidate is rejected.

False negatives are permitted because they only lose performance.

Initial qualification is stateless. No accepted cache, continuation state, checkpoint field, restart change or history-dependent ownership is allowed.

## Candidate observables

Cheap trial-start observables to test include pressure head, water content, saturated water content / air-filled porosity, rooted-node mask, temperature, and existing immutable soil/crop parameters. Candidate rules must be justified by the admitted equations or exhaustive falsification over a preregistered state sweep; correlation alone is insufficient.

## Experiment

Generate a broad deterministic sweep over admitted analytical-MvG REFERENCE states, including wet transition states, temperatures and rooted profiles. For every state:
- evaluate cheap observables;
- run the complete admitted Bartholomeus Reference route;
- record minimum rooted factor;
- classify no-stress versus stress;
- evaluate candidate sufficient gates.

Report confusion counts, especially false-positive skips, and the skip fraction. Include boundary-focused sweeps around any proposed threshold.

## Performance

After a zero-false-positive gate is identified, benchmark:
- current PERF01 route;
- gated route over mixed workloads;
- gated route restricted to calls that still require Bartholomeus.

This preserves visibility of both call-elimination gain and remaining per-call overhead.

## Admission boundary

PERF02 does not broaden C3A physics. Any history-aware suppression or approximate gate requires a later work unit.
