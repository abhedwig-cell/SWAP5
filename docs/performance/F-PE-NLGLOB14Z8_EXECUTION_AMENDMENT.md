# F-PE-NLGLOB14Z8 execution amendment — fine-dt checkpoint partition

Date: 2026-09-29

Status: `EXECUTION_ONLY_AMENDMENT_BEFORE_FINE_RESULT_EXPOSURE`

Scientific preregistration authority remains:

`docs/performance/F-PE-NLGLOB14Z8_PREREGISTRATION.md`

No scientific fixture, horizon, timestep, forcing, solver tolerance, ownership rule, mass gate, residual gate or classification is changed.

## Reason

The combined Z8 run and subsequent fine-dt matrix runs were externally terminated by GitHub-hosted runner shutdown signals before any fine-dt numerical result was emitted.

Observed infrastructure behavior:

- combined 4-fixture job: external shutdown before result;
- exact rerun: external shutdown before result;
- partitioned coarse dt=1.25e-4 fixtures: complete successfully;
- partitioned fine dt=6.25e-5 fixtures: externally shutdown before result, including solo rerun.

No solver failure classification exists for the interrupted fine fixtures.

## Execution partition

For each fine dt=6.25e-5 fixture only, execute the unchanged 25.60 d trajectory in two sequential infrastructure jobs:

1. segment A: accepted trajectory from original origin through 12.80 d;
2. serialize exact accepted split research state at 12.80 d;
3. segment B: restore that exact accepted state and continue from 12.80 d through 25.60 d.

The checkpoint must include all state needed to preserve trajectory authority:

- pressure head vector;
- water-content vector;
- accepted temporal ownership / saturated-tail geometry;
- accepted counters and event history needed by Z8 diagnostics;
- maximum mass/residual/rollback diagnostics accumulated so far.

The checkpoint is a transport mechanism only. It may not modify values.

## Transaction and continuity gates

Require:

- checkpoint write/read roundtrip exact for h and theta;
- resumed accepted saturated set equals segment-A final set exactly;
- resumed temporal ownership equals segment-A final ownership exactly;
- no synthetic event is inserted at the segment boundary;
- segment-B first interval begins from the exact segment-A accepted endpoint;
- aggregate mass/residual/rollback maxima cover both segments.

If checkpoint continuity fails, classify infrastructure execution as invalid; do not infer a physical result.

## Result aggregation

The original frozen Z8 aggregate still requires all four preregistered fixtures.

The two already completed dt=1.25e-4 fixture results remain valid.

The two fine fixtures qualify only after segment A + B jointly satisfy the original 25.60 d gates.

## Production boundary

Research harness execution only.

No production `src/**` change.
