# F-PE-NLGLOB13C closeout — near-saturation overshoot scaling

Date: 2026-09-29

Final status:

`BLOCKED_NLGLOB13C_SCALING_COVERAGE`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@ef08f11b5576bec92d66c445e0c577e680215487`

Qualification authority:

- run `36556318878`;
- job `109366213738`;
- conclusion: SUCCESS.

## Closure

NLGLOB13C does not qualify the overshoot-contraction hypothesis because the preregistered same-pre-state identity gate fails in 2/7 paired h/2 -> h/4 comparisons.

The raw scaling signal is nevertheless coherent:

- 7/7 pairs contract;
- median h/4-to-h/2 overshoot ratio about `0.462`;
- median apparent exponent about `1.11`.

That signal remains provisional until the identity blocker is resolved.

## Direct successor

Open:

`F-PE-NLGLOB13C1 — failing-half pre-state identity reconciliation`.

The successor must remain diagnostic only.

It must compare, node by node, the exact pre-state presented to:

1. the failing h/2 trial;
2. the corresponding h/4 retry after rollback.

At minimum record:

- max absolute and ULP-normalized moisture difference;
- max absolute and ULP-normalized pressure-head difference;
- ponding difference;
- volume-weighted moisture-storage difference;
- route identity;
- finite-state status.

No solver behavior, subdivision depth or acceptance rule may change.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB13C

BASELINE: `ef08f11b5576bec92d66c445e0c577e680215487`

BRANCH: `research/f-pe-nlglob13c-overshoot-scaling`

STATUS: blocked on diagnostic identity coverage

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `BLOCKED_NLGLOB13C_SCALING_COVERAGE`

NEXT SAFE STEP: preregister NLGLOB13C1 exact pre-state identity reconciliation

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
