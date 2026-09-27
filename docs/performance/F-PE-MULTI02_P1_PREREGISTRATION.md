# F-PE-MULTI02 P1 preregistration — discrete-route and ownership authority

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Parent:
`F-PE-MULTI02 P0`

P0 authority:
- worker-local serialized ownership: q/tangent identity PASS;
- N=1,000 2-worker speedup: 1.893x;
- N=1,000 4-worker speedup: 2.360x;
- max simultaneous real solves: 2 and 4;
- frozen performance gates: PASS.

## Purpose

P1 determines whether the worker-local parallel candidate preserves the exact discrete transaction/solver route, not only final q and tangent values.

No production source change is authorized.

## Frozen workload

Use the same homogeneous production-shaped P0 workload:

- mode 5 fixed-interface groundwater;
- temporal-history continuation;
- c=0.65 history-aware budget;
- TEMPORAL08-compatible history seed;
- accepted-origin head;
- independent tile state;
- worker-local mutable Reference backends;
- static deterministic worker assignment.

Primary authority sizes:
- N=100;
- N=1,000.

Worker counts:
- 1;
- 2;
- 4.

## Required per-tile identity

Expose read-only research diagnostics from each participant after the trial and compare parallel arms against the 1-worker authority.

Require exact equality for:

- transaction calls;
- accepted substeps;
- attempts;
- retries;
- solver rejections;
- temporal rejections;
- internal retries;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- temporal acceptance source where available.

Also preserve:

- q within roundoff;
- accepted-trajectory tangent within roundoff;
- tangent availability/provenance;
- candidate presence after successful trial;
- no committed revision mutation before commit.

## Discard authority

After discard require for every participant:

- no live candidate;
- captured origin remains valid;
- committed revision unchanged;
- registry is quiescent with respect to candidates;
- repeated replay from the same origin reproduces the same q, tangent and diagnostics.

## Parallel ownership authority

P1 must prove that:

- each concurrently active worker uses only its own mutable backend/workspace;
- no backend instance is entered concurrently by more than one worker;
- worker assignment is deterministic for the frozen schedule;
- aggregate output order is independent of completion order.

## Performance preservation

P1 is primarily semantic.

The P0 performance result must nevertheless remain broadly reproducible:
- N=1,000 2-worker speedup >= 1.5x;
- N=1,000 4-worker speedup >= 2.2x.

A semantic pass with performance collapse does not advance.

## Advancement

Only after P1 passes may MULTI02 open a production-shaped application-context integration candidate.

That next stage must retain the existing serialized route as fallback/default until independent admission.

## Failure outcomes

P1 closes or redirects on:

- any discrete-route divergence;
- any candidate/origin/revision leak;
- any shared-backend concurrency;
- nondeterministic aggregate output;
- failure of either frozen large-N speed gate.
