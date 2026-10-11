# F-PE-BASE01 P1 preregistration — backend internal decomposition

Date: 2026-09-27

Status: `PREREGISTERED_OBSERVATION_ONLY`

Parent:
`F-PE-BASE01 P0`

P0 authority:
- exact SWAP trial time: `1,894,357 ns`;
- serialized backend time: `1,578,403 ns`;
- backend share: `83.3213%`.

## Primary question

Within the current base q/state serialized Reference backend used by unavoidable live corrector trials, which numerical work family dominates wall-clock cost?

## Frozen population

Use the same 12 material/regime/history groups as BASE01 P0.

Preserve:

- TEMPORAL08 c=0.65 history-aware effective budget;
- BALTOL02;
- exact Reference solver;
- same accepted/retry trajectory;
- tangent disabled identically when measuring the base q/state path;
- no production source change.

## Required timing families

Instrument generated research copies so that backend time is partitioned, as far as technically separable, into:

1. transaction / substep / retry orchestration;
2. nonlinear solve body;
3. constitutive provider work;
4. residual and Jacobian assembly/update;
5. tridiagonal linear solve;
6. backtracking candidate loop, including candidate state update and progress evaluation;
7. accepted-state / transaction-candidate materialization;
8. remaining backend overhead.

Nested timings must be reported explicitly and must not be added as if disjoint when they overlap.

## Required counters

Retain per group:

- attempts;
- accepted substeps;
- temporal rejections;
- solver rejections;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- constitutive evaluations;
- candidate-demand evaluations where available;
- backtracking attempts.

## Perturbation control

The instrumented path must preserve the discrete numerical trajectory relative to the uninstrumented BASE01 P0 path:

- same exact trial count;
- same attempts/retries;
- same nonlinear/backtracking counts;
- exact q identity or roundoff-only equality;
- no new solver failure.

If instrumentation changes the discrete trajectory, P1 is blocked until a lower-perturbation measurement is available.

## Target-selection gate

P1 does not admit an optimization.

A work family may advance to P2 target discrimination only when it contributes:

- at least `20%` of aggregate base q/state backend time, or
- at least `15%` broadly across the difficult live groups.

The percentage must come from current BASE01 measurements, not historical gprof.

## Historical evidence boundary

NEWTON-CANDIDATE01 previously showed that difficult high-backtracking Reference solves can shift cost toward candidate hydraulic demand and HeadCalc candidate/residual/control work.

That is hypothesis guidance only.

BASE01 must determine whether the same structure controls the current TEMPORAL08 live population.

## Non-goals

P1 does not:

- retune c=0.65;
- change temporal floor or retry policy;
- change nonlinear tolerances;
- change line search;
- change constitutive representation;
- alter accepted-direction mathematics;
- infer a production patch from historical AHL timings.

## Closeout of P1

Close P1 with a ranked current-live backend cost map and either:

- `ADVANCE_<TARGET>_TO_P2`, or
- `NO_SINGLE_MATERIAL_BACKEND_TARGET`.
