# F-PE-PZG23-05 — backtracking descent instrumentation

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH

Baseline:
`integration/f-ci-canonical@c400b02d9956f35c9c20fac09f94b34d5e2ee09f`

Parent authority:
- PZG23-01 localized interval-B failure to origins 10 and 11;
- PZG23-02 falsified accepted temporal-history content and hidden solver scratch;
- PZG23-03 showed solver rejection dominates;
- PZG23-04 showed doubling max_iterations from 32 to 64 is not sufficient.

## Purpose

Determine whether the remaining pZg23 blocker is characterized primarily by:

1. repeated exhaustion of the HeadCalc backtracking search;
2. failure of the Newton direction to provide any residual decrease even at
   very small damping factors;
3. or a different convergence-criterion conflict.

This workunit is diagnostic only.

## Frozen cases

Profile:
`90210030 / pZg23`.

Origins:

- origin 10: h0=+2 cm, delta=+0.035 cm/day;
- origin 11: h0=+2 cm, delta=+0.050 cm/day.

Use the production configuration unchanged:

- GENERATED ELAS;
- bottom_mode=7;
- swkimpl=0;
- RICHARDS_TEMPORAL_HISTORY;
- caller-owned head budget=0.20 cm;
- max_iterations=32;
- max_backtracking=12;
- max retries=8;
- all balance/head tolerances unchanged;
- hard mass unchanged.

## Instrumentation method

Do not modify production `src/**`.

Materialize a temporary research-only copy of
`src/legacy/b1_10_port/headcalc.f90` during the test build.

Instrument only local HeadCalc diagnostics.

For every HeadCalc call record:

- explicit step duration;
- nonlinear iterations used;
- total backtracking attempts;
- number of nonlinear iterations where a damped Newton step reduced
  `sump = 0.5 * ||F||^2`;
- number accepted only because `Fmax < CritDevBalCp`;
- number of nonlinear iterations that exhausted all `MaxBackTr` attempts
  without satisfying either progress condition;
- best observed `sump/sumold` ratio;
- smallest actually attempted damping factor;
- terminal `Fmax`;
- whether HeadCalc returned converged or requested dt reduction.

The production decision rule remains unchanged:

`sump < sumold OR Fmax < CritDevBalCp`.

## Hypotheses

H1 — backtracking-search exhaustion dominates:

Supported if failed HeadCalc calls contain repeated full-loop exhaustions.

H2 — Newton direction is locally non-descent:

Supported if failed calls repeatedly reach very small damping factors while the
best `sump/sumold >= 1`.

H3 — backtracking-depth ceiling is a plausible repair target:

Only supported if failed calls frequently exhaust all 12 attempts and their
best residual ratio approaches 1 from above in a way consistent with additional
damping plausibly crossing below 1.

If the best ratio remains materially above 1 even at the smallest attempted
factor, extra backtracking depth is not justified.

## Stop rule

Close after instrumentation and classification.

Do not:

- change MaxBackTr;
- change MaxIt;
- change retry count;
- change tolerances;
- change temporal budget;
- change physics;
- implement a production repair.

Any repair workunit must be justified by PZG23-05 evidence.
