# F-PE-PROFILE07 — exact live-corrector cost decomposition

Date: 2026-09-27

Status: `PREREGISTERED_OBSERVATION_ONLY`

Parent evidence:
`F-PE-SOLVE01 / PR #654`

Parent head:
`27711ef356cd8730a79ed31dccb99474dc28eb2b`

Branch:
`work/f-pe-profile07-live-exact-trial-cost`

## Trigger

SOLVE01 closed discarded-trial solve elimination as a conditional optimization that is not justified by the tested live MODFLOW6 corrector demand.

The decisive live observations were:

- 8/12 difficult groups require only two exact SWAP trials;
- 4/12 require four exact SWAP trials;
- no live group requires five or more;
- E4 removes 43.75% of exact SWAP trials across the matrix but still makes aggregate live runtime 6.10% slower because external iteration and validation overhead dominate.

Therefore the performance line returns to the exact work that live coupling actually performs.

## Primary question

Within one production-shaped exact live SWAP corrector trial, where is wall-clock time spent, and which measured component is large enough to justify a new exact-preserving optimization workunit?

## Scope

PROFILE07 is observation-only.

No `src/**` modification is allowed.

The workunit may add:

- research harnesses;
- timing instrumentation in generated test copies;
- documentation;
- CI workflows.

Instrumentation must not alter production source or accepted numerical behavior.

## Frozen live matrix

Use the exact E0 arm from the P2B authority:

- B01 wet, h0=-10 cm, history -10%;
- B01 wet, h0=-10 cm, history +10%;
- B01 mid, h0=-75 cm, history -10%;
- B01 mid, h0=-75 cm, history +10%;
- B12 wet, h0=-10 cm, history -10%;
- B12 wet, h0=-10 cm, history +10%;
- O05 wet, h0=-10 cm, history -10%;
- O05 wet, h0=-10 cm, history +10%;
- O14 wet, h0=-10 cm, history -10%;
- O14 wet, h0=-10 cm, history +10%;
- O14 mid, h0=-75 cm, history -10%;
- O14 mid, h0=-75 cm, history +10%.

MODFLOW6 authority remains 6.8.0.

## Cost buckets

Measure, at minimum, the following per exact corrector trial where instrumentation permits:

1. forcing materialization;
2. origin/checkpoint validation and transaction setup;
3. serialized Reference Richards solve;
4. accepted-trajectory directional response/tangent work;
5. candidate/result materialization;
6. discard/rollback of rejected exact trials;
7. final-validation and publication preflight overhead;
8. external MODFLOW prepared-solve time, reported separately from SWAP.

Do not combine MODFLOW and SWAP time into one unexplained bucket.

## Richards internal attribution

For the exact Richards solve, also report:

- accepted substeps;
- attempts/retries;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- HEADCALC calls where available;
- backtracking attempts;
- temporal rejections;
- solver rejections.

The purpose is to distinguish:

- repeated physical solves;
- nonlinear iteration work;
- accepted-direction work;
- transaction/orchestration overhead.

## Measurement method

Use paired/repeated measurements and report medians.

Instrumentation overhead must be characterized.

Where direct timers inside a generated research copy are used, compare the instrumented total against the uninstrumented exact E0 wall-clock to ensure attribution does not materially perturb the ranking.

## Advancement rule

PROFILE07 does not admit an optimization.

It may nominate a successor only when a measured component satisfies both:

1. material contribution to exact live SWAP trial cost, preferably >=10% median on at least one relevant difficult class or >=5% broadly across the live matrix;
2. a concrete exact-preserving mechanism exists to reduce or avoid that work without changing accepted physical state, timestep, mass, derivative semantics or external MODFLOW iteration behavior.

Small components may still be documented, but they should not spawn a workunit merely because they are measurable.

## Explicit non-goals

PROFILE07 does not:

- reopen E4/EH cadence tuning;
- relax live coupling tolerances;
- introduce a response surrogate;
- change temporal policy;
- change Richards physics;
- modify MODFLOW solver settings;
- claim a speedup from microbenchmarks alone.

## Closeout

Close with:

- a ranked exact-live cost map;
- measured shares and absolute times;
- one recommended next target at most;
- or `CLOSED_NO_MATERIAL_EXACT_TARGET` if no component justifies another optimization line.
