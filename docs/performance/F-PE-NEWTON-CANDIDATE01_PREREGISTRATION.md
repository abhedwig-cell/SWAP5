# F-PE-NEWTON-CANDIDATE01 — exact Reference candidate/backtracking decomposition

Date: 2026-09-25

Status: `PREREGISTERED_DECOMPOSITION`

Production parent: F-PE-PLANVALID01 admitted postimage `df664f56cf09ee8479701f15fe10ee02d31a9536`.

## Purpose

PROFILE02 established that difficult Reference runtime is dominated by work repeated inside the candidate/backtracking loop.

This workunit asks:

> Which exact subcomponents of one Reference backtracking candidate consume the time, and which of them can be made cheaper without changing Newton mathematics, line-search policy, tolerances, failure timing, water balance or accepted-state semantics?

## Current candidate loop

Current HeadCalc performs, per backtracking candidate:

1. pressure-head candidate update;
2. hydraulic candidate evaluation;
3. candidate theta assignment;
4. head-gradient update;
5. implicit-conductivity/root work when `SWKIMPL=1`;
6. residual recomputation through `vector_F(2)`;
7. residual reductions: inner product, sum and max absolute value;
8. progress test and factor reduction when rejected.

On the PROFILE02 explicit-conductivity difficulty route, hydraulic candidate evaluation is primarily a theta-only demand.

## Measurement before repair

No production optimization is authorized before current-postimage decomposition.

Initial measurement must compare at least:

- an easy accepted case;
- a high-backtracking/retry-advised case from the frozen PUB-P2E04 domain.

Required attribution:

- candidate hydraulic demand;
- residual recomputation;
- residual reductions/control;
- Jacobian build;
- linear solve;
- total solve;
- call counts for each repeated block.

Use test-only instrumentation or profiling. Do not add production timers to the accepted runtime path.

## Candidate classes after measurement

Potential exact repairs may include:

- B: reuse of candidate-invariant exact quantities;
- B/C: cheaper exact residual evaluation or reduction;
- C: avoidable repeated control work with identical candidate sequence;
- D: hydraulic-demand cost, handed to F-AHL if representation changes are required.

No change to candidate sequence, factor schedule, convergence thresholds or accepted/rejected outcome is permitted without a separately preregistered algorithmic sub-workunit.

## F-AHL firewall

F-PE-NEWTON-CANDIDATE01 may measure hydraulic-demand cost and may reduce non-representation overhead.

It must not implement a competing theta/C/K interpolation or lookup representation. Such implementation belongs to F-AHL.

## Closeout target

Select at most one bounded exact production repair from this workunit, or close with no repair if the dominant measured cost belongs to F-AHL or to necessary numerical work.
