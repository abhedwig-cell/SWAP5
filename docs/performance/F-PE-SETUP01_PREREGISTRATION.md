# F-PE-SETUP01 — large-N groundwater setup decomposition

Date: 2026-09-27

Status: `PREREGISTERED_OBSERVATION_ONLY`

Parent:
`F-PE-MULTIPROC04 / PR #674`

Parent head:
`d4bcd454dde26e0204a116b037b0061280eccb19`

Branch:
`work/f-pe-setup01-groundwater-context-materialization`

## Trigger

MULTIPROC04 showed that process partitioning is not a persistent steady-state win, but large-N launch-to-READY cost is substantial:
- N=10,000, 1x4: about 0.76 s;
- N=40,000, 1x4: about 6.76 s.

That launch interval combines several distinct lifecycle costs.

## Purpose

Decompose large-N production-shaped groundwater setup into:
1. fixture/config construction;
2. `app%initialize(config)` production bootstrap;
3. reference-head/topology/predictor preparation;
4. `app%materialize_groundwater_context(...)`;
5. first accepted-origin capture + warm trial/tangent/discard.

The immediate decision is whether the large N-dependent cost is predominantly:
- one-time application bootstrap;
- recurring coupling-window context materialization;
- first-use warm-up.

## P0 matrix

Production-shaped TEMPORAL08 fixture with worker count 4:
- N=1,000;
- N=10,000;
- N=40,000.

Use three fresh-process repetitions per N and report medians.

No timing phase may be inferred by subtraction from process startup alone; phase boundaries are instrumented explicitly in research-only fixture copies.

## Interpretation

Select a recurring setup optimization only if `materialize_groundwater_context` or per-window preparation owns at least 15% of measured total setup at N=10,000 or N=40,000 and has material absolute cost.

If `app%initialize` dominates:
- classify the cost primarily as one-time model bootstrap;
- do not mix it with coupling-window runtime;
- only optimize it if expected production startup frequency makes the cost material.

If warm-up dominates:
- investigate first-use cache/provider initialization separately.

## Production boundary

Observation-only.
No production `src/**` changes.
No changes to physics, tolerances, temporal policy, worker scheduling, transaction semantics or coupling equations.
