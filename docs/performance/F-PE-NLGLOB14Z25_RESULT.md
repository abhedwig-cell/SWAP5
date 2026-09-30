# F-PE-NLGLOB14Z25 result — internal chatter execution-burden attribution

Date: 2026-09-30

Status:

`QUALIFIED_Z25_NO_TIMESTEP_RETRY_BURDEN_OPERATION_COST_UNRESOLVED`

Qualification authority:

- workflow run: `36722547343`;
- burden-attribution job: `109911085800`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

Research postimage before result persistence:

`research/f-pe-nlglob14z25-chatter-burden@747f66fd52a33e5874cd82aab801e34735a74263`

## Result

Both fine O05 fixtures classify:

`CHATTER_ON_NOMINAL_ACCEPTED_INTERVALS_ONLY`.

No frozen evidence shows chatter causing:

- timestep retry;
- step halving;
- inserted substeps;
- rejected time-advancing accepted states;
- rollback leakage;
- extra physical intervals.

The separate operation-cost classification is:

`OPERATION_COST_UNRESOLVED`.

The frozen evidence contains no per-interval Newton-iteration counts, operation counters or timings from which nonlinear work attributable to chatter can be quantified.

## HEAD fine

- nominal dt: 6.25e-5 d;
- observed nominal intervals after the committed reverse origin: 4,465,063;
- ownership events including the committed reverse: 15;
- consecutive chatter bursts: 2;
- burst lengths: 6 and 9 intervals;
- total chatter-span intervals: 15;
- chatter-span fraction of nominal intervals: about 3.36e-6;
- exact nominal dt preserved within bursts;
- hard mass/residual/rollback gates valid;
- explicit retry/substep evidence: none.

## RUNOFF fine

- nominal dt: 6.25e-5 d;
- observed nominal intervals after the committed reverse origin: 4,465,114;
- ownership events including the committed reverse: 11;
- consecutive chatter bursts: 2;
- burst lengths: 6 and 5 intervals;
- total chatter-span intervals: 11;
- chatter-span fraction of nominal intervals: about 2.46e-6;
- exact nominal dt preserved within bursts;
- hard mass/residual/rollback gates valid;
- explicit retry/substep evidence: none.

## Interpretation

The repeated ownership chatter is not creating a temporal-refinement cascade in these fixtures.

That removes one important concern: chatter does not itself inflate the trajectory by adding retry intervals or smaller substeps.

The small fraction of event intervals must not be interpreted as an equally small runtime fraction. Internal ownership changes alter the split geometry and may change nonlinear system size, Newton iteration count or constitutive work on those intervals and immediately surrounding intervals.

Those costs are not present in the frozen evidence.

## Qualified claim boundary

Qualified:

- no timestep retry/substep burden attributable to chatter in the two frozen fine trajectories;
- no extra physical intervals inserted by chatter;
- chatter occurs entirely on nominal accepted intervals;
- operation-level runtime burden remains unresolved.

Not qualified:

- zero runtime overhead;
- negligible solver cost;
- no effect on Newton iteration count;
- no effect on constitutive work;
- broader fixture portability.

## Consequence

The next safe successor is a narrowly instrumented event-window cost study.

It should measure solver work around:

- the first 12:16/13:16 chatter burst;
- the later 13:16/14:16 chatter burst;
- matched stable intervals before and after each burst.

The study must not suppress chatter or alter physical semantics.

## Production boundary

Research only. No production source/default change.

`LEGACY_NUMERICS` remains production default.
