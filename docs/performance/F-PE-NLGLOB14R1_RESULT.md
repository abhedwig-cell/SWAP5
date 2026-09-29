# F-PE-NLGLOB14R1 result — post-handoff second-interval endpoint failure attribution

Date: 2026-09-29

Status:

`NLGLOB14R1_UNIFORM_SECOND_INTERVAL_RETRY_ADVISED`

Qualification authority:

- workflow run: `36591512007`;
- job: `109485510278`;
- conclusion: SUCCESS.

## Frozen question

What mechanism causes the uniform second TG interval failure immediately after the accepted first-retreat TG handoff?

## Coverage

PASS.

All 12 frozen O05 six-level fixtures:

- reproduce the accepted first TG handoff interval;
- enter the same immediate-following second TG interval;
- reproduce the harness-level `ENDPOINT_SOLVE_FAILURE`;
- remain finite and mass-clean before the failed candidate;
- preserve surface-flux origin and predictor routes.

## Solver attribution

All 12 second-interval endpoint solves return:

- solver status = `2`;
- retry advised = true;
- diagnostic route = `legacy-reference-retry`;
- nonlinear iterations = `8`;
- Jacobian builds = `8`;
- linear solves = `8`;
- internal retries = `1`;
- alternative solver calls = `0`.

Backtracking attempts range from 11 to 16 across fixtures.

Therefore every fixture classifies:

`SECOND_INTERVAL_RETRY_ADVISED`.

Frozen aggregate classification:

`NLGLOB14R1_UNIFORM_SECOND_INTERVAL_RETRY_ADVISED`.

## Physical admissibility

Accepted physical state before the failed second interval remains mass-clean:

- max interval ledger about `2.68e-14 cm`;
- max cumulative ledger about `9.12e-14 cm`.

No accepted-state inconsistency, route inconsistency or hard solver-contract failure is observed.

## Scientific interpretation

The first-retreat TG handoff itself remains valid for one accepted interval.

The immediate continuation does not hard-fail. The Reference solver uniformly asks the caller for a smaller step on the next interval.

Therefore NLGLOB14R does not establish unstable TG ownership, and it does not establish saturation-mode chatter.

The next bounded question is whether the existing transaction/retry semantics can continue TG ownership by retrying the same second interval at the already-qualified retry scale, without changing release timing, solver tolerances or physical acceptance rules.

## Consequence

Open a separately preregistered successor that reuses the existing transaction retry contract rather than inventing a new step reduction.

The successor must preserve:

- the accepted first TG handoff state;
- the exact second-interval origin;
- dry forcing and surface-flux route semantics;
- rollback of the retry-advised failed candidate;
- existing solver limits and tolerances;
- saturation re-entry machinery.

No production release rule is authorized by NLGLOB14R1.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No numerical default or production temporal-mode ownership changed.

`LEGACY_NUMERICS` remains production default.
