# F-PE-NLGLOB14N2 closeout — fine-dt root-trial endpoint-solver decomposition

Date: 2026-09-29

Final status:

`RETRY_ADVISED_AT_ROOT_TRIAL`

Qualification authority:

- run `36583443477`;
- job `109457419142`;
- conclusion: SUCCESS.

## Closure

NLGLOB14N2 closes the endpoint-solver decomposition for the single finest HEAD blocker.

The root trial does not fail through route inconsistency, workspace/type failure or an identified linear-solver exception.

The solver explicitly requests retry:

- route `legacy-reference-retry`;
- retry advised = true;
- nonlinear iterations = 8;
- backtracking attempts = 8;
- Jacobian builds = 8;
- linear solves = 8;
- internal retries = 1;
- alternative solver calls = 0.

The trial duration is about `1.34e-6 d`.

## Scientific conclusion

The current saturation-root controller conflates a solver retry request with an unrecoverable root-trial failure.

That is the direct mechanism blocking the finest HEAD NLGLOB14N trajectory.

No evidence from NLGLOB14N2 supports changing tolerances or iteration budgets.

## Direct successor

Open:

`F-PE-NLGLOB14N3 — saturation-root retry-as-bracket contraction falsification`.

The successor may change only research-harness root-controller handling:

1. when a root trial returns solver retry-advised semantics;
2. restore the saved accepted state and accounting;
3. do not accept the failed candidate;
4. move `phi_hi` to the failed `phi_mid`;
5. continue the existing bisection.

All other failures retain current fail-closed behavior.

The successor must test:

- target finest HEAD blocker removal;
- no rejected-state leakage;
- valid localized saturation entry;
- physical mass;
- unchanged route semantics;
- unchanged older NLGLOB/TIMEINT behavior;
- and, if the target completes, rerun the unchanged NLGLOB14N refined retreat-convergence gate.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14N2

BASELINE: `12e12538f043c6716086615ea51c8b87610600c4`

BRANCH: `research/f-pe-nlglob14n2-root-trial-solver-decomposition`

STATUS: closed positive mechanism attribution

TEST STATUS: focused target-fixture run PASS

QUALIFICATION STATUS: `RETRY_ADVISED_AT_ROOT_TRIAL`

NEXT SAFE STEP: preregister NLGLOB14N3 retry-as-bracket-contraction falsification.

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
