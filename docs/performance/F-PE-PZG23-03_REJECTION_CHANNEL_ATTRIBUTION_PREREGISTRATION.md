# F-PE-PZG23-03 — interval-B rejection-channel attribution

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH

Baseline:
`integration/f-ci-canonical@f133e47f8f7899f3d70db79f9ea63fbb730b2da0`

Parent authority:
- F-PE-PZG23-01 localized the blocker to origins 10 and 11;
- F-PE-PZG23-02 falsified accepted temporal history and hidden solver scratch as primary causes.

## Purpose

Attribute the failed interval-B transaction to explicit kernel rejection
channels without changing solver policy.

This workunit is diagnostic only.

## Frozen cases

Profile:
`90210030 / pZg23`.

Origins:

- origin 10: h0 = +2 cm, delta = +0.035 cm/day;
- origin 11: h0 = +2 cm, delta = +0.050 cm/day.

Configuration remains:

- exact frozen BRO/BOFEK geometry;
- exact Staringreeks retention;
- GENERATED ELAS;
- bottom_mode = 7;
- swkimpl = 0;
- RICHARDS_TEMPORAL_HISTORY;
- explicit caller-owned head budget = 0.20 cm;
- dt = 0.015625 day;
- max retries = 8;
- worker count = 1.

## Method

For each origin:

1. run interval A through the ordinary serialized production transaction path;
2. require interval A complete, committed and mass-complete;
3. capture the exact committed checkpoint at t=dt;
4. call the existing serialized backend `run_trial` directly for interval B
   from that checkpoint using the unchanged numerical configuration;
5. record the returned `kernel_diagnostics_t` rejection counters.

No candidate is committed by the diagnostic B call.

## Diagnostics

Record:

- solver_rejections;
- temporal_rejections;
- temporal_certificate_unavailable_rejections;
- mass_rejections;
- admission_rejections;
- checkpoint_rejections;
- nonlinear iterations;
- internal retries;
- HeadCalc calls;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- accepted substeps;
- transaction attempts/retries;
- min/max accepted substep duration;
- max temporal indicator;
- max absolute step mass residual;
- B completion status and mass publication.

## Hypotheses

H1 — solver rejection channel dominates:

Supported if `solver_rejections > 0` while hard-mass rejection is zero and the
failure terminates without a complete candidate.

H2 — temporal-certificate rejection dominates:

Supported if `temporal_rejections > 0` is the terminal/refinement-driving
channel while solver rejection is absent or secondary.

H3 — hard mass causes the failure:

Supported only if `mass_rejections > 0` on an otherwise complete physical
candidate.

## Stop rule

Close after channel attribution.

Do not:

- change retry count;
- change nonlinear/backtracking limits;
- change any tolerance;
- change temporal budget;
- change ELAS;
- implement a repair.

A repair workunit is allowed only if PZG23-03 identifies a bounded rejection
mechanism with a clear causal target.
