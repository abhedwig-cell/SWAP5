# F-PE-SETUP05 — post-admission large-N setup reprofile

Date: 2026-09-27

Status: `PREREGISTERED_OBSERVATION_ONLY`

Canonical parent:
`integration/f-ci-canonical@71813645a5acbacd7cd900aee6f619dc1039e8e1`

Parent admission:
`F-PE-SETUP04 / PR #681`

Branch:
`work/f-pe-setup05-post-admission-reprofile`

## Purpose

Re-measure production-shaped large-N setup after SETUP04 removed the dominant quadratic bootstrap scans.

The goal is to identify whether any setup family still owns enough wall time to justify another optimization workunit.

## Matrix

Production-shaped TEMPORAL08 groundwater fixture, 4 workers:
- N=1,000;
- N=10,000;
- N=40,000.

Five fresh-process repetitions per N.

Measure separately:
- configuration construction;
- `app%initialize`;
- topology/predictor construction;
- groundwater-context materialization;
- origin capture;
- first warm trial + tangent + discard;
- total setup through warm-up.

## Selection rule

Advance exactly one setup family only if, at N=40,000, it:
- owns >=25% of total setup through warm-up; and
- costs >=0.25 s absolute wall time; and
- is not simply the already-qualified repeated physical trial cost.

If no family clears all three conditions, close the setup-optimization line as low expected return.

## Production boundary

Observation-only.
No `src/**` change.
No physics, solver, temporal, tangent, worker scheduling, coupling, transaction or publication change.
