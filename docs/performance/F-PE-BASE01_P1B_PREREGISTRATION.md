# F-PE-BASE01 P1B preregistration — non-HeadCalc backend decomposition

Date: 2026-09-27

Status: `PREREGISTERED_OBSERVATION_ONLY`

Parent:
`F-PE-BASE01 P1`

P1 authority:
- backend aggregate: `461628 ns`;
- HeadCalc aggregate: `202372 ns`;
- HeadCalc share: `43.8388%`;
- unresolved non-HeadCalc backend share: approximately `56.16%`.

## Question

Where does the non-HeadCalc half of the current q/state serialized Reference backend go?

## Frozen population

Use exactly the same frozen q-only LIVE01 head sequences and the same c=0.65 temporal-history policy as P1.

Preserve the discrete trajectory:

- 52 transaction calls;
- 52 accepted substeps;
- 72 attempts;
- 20 retries;
- 20 temporal rejections;
- 0 solver rejections;
- 236 nonlinear iterations;
- 236 backtracking attempts.

## Required disjoint or explicitly nested timing families

Measure, as far as technically separable:

1. solver/HeadCalc call envelope;
2. temporal-indicator / temporal-certificate evaluation;
3. retry/substep orchestration outside the physical solve;
4. checkpoint/state snapshot or restore work;
5. candidate/result/state materialization and copying;
6. mass/result bookkeeping and acceptance checks;
7. remaining backend overhead.

If a timing family nests another, report that explicitly. Do not add nested percentages.

## Perturbation rule

Instrumentation must not change the frozen discrete trajectory.

Any new solver rejection, changed retry count, changed nonlinear count or changed q sequence blocks attribution until the instrumentation is repaired.

## P2 selection gate

After P1B, exactly one work family may advance only if:

- it contributes at least 20% of aggregate q/state backend runtime, or at least 15% broadly across the difficult groups; and
- there is a concrete exact-preserving mechanism to reduce or remove that work.

If no family satisfies both, BASE01 closes `CLOSED_NO_EXACT_BASE_SOLVE_TARGET`.

## Non-goals

P1B does not retune tolerances, c=0.65, temporal floor, retry scale, tangent mathematics, constitutive representation or MODFLOW behavior.
