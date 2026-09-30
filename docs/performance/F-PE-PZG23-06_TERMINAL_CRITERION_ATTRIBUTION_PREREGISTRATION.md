# F-PE-PZG23-06 — terminal convergence-criterion attribution

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH

Baseline:
`integration/f-ci-canonical@c400b02d9956f35c9c20fac09f94b34d5e2ee09f`

Parent authority:
- PZG23-01 localized failure to origins 10 and 11;
- PZG23-02 falsified accepted temporal-history content;
- PZG23-03 showed solver rejection dominates;
- PZG23-04 showed max_iterations=64 is insufficient;
- PZG23-05 showed backtracking-depth exhaustion is not the primary terminal mechanism.

## Purpose

Identify which explicit HeadCalc convergence criterion remains violated at the
terminal nonlinear state of failed interval-B solver calls.

This workunit is diagnostic only.

## Frozen cases

Profile:
`90210030 / pZg23`.

Origins:

- origin 10: h0=+2 cm, delta=+0.035 cm/day;
- origin 11: h0=+2 cm, delta=+0.050 cm/day.

Production configuration remains unchanged:

- GENERATED ELAS;
- bottom_mode=7;
- swkimpl=0;
- RICHARDS_TEMPORAL_HISTORY;
- caller-owned head budget=0.20 cm;
- max_iterations=32;
- max_backtracking=12;
- max retries=8;
- all balance/head/ponding tolerances unchanged;
- hard mass unchanged.

## Instrumentation

Production `src/**` must not change.

Materialize the already qualified PZG23-05 instrumented HeadCalc copy, then add
research-only terminal criterion logging immediately after nonlinear-loop
exhaustion and before HeadCalc resets the trial state.

For every failed HeadCalc call record dimensionless terminal ratios:

### Compartment balance ratio

`R_comp = max(abs(residual_i)) / CritDevBalCp`.

### Total balance ratio

`R_total = abs(sum(residual_i)) / CritDevBalTot`.

### Pressure-head change ratio

For each node:

- if `abs(old_head)<1 cm`:
  `abs(h-old_head)/CritDevh2Cp`;
- otherwise:
  `abs(h-old_head)/abs(old_head)/CritDevh1Cp`.

Record the maximum over nodes as `R_head`.

### Ponding ratio

Where the top boundary is in head/ponding mode, record:

`R_pond = abs(deviat)/CritDevPondDt`.

Otherwise record zero and the inactive top-head flag.

A criterion is satisfied when its ratio is <=1.

## Hypotheses

H1 — compartment-balance gate dominates:

Supported if failed calls systematically terminate with `R_comp>1` while the
other applicable ratios are <=1 or substantially smaller.

H2 — total-balance gate dominates:

Supported analogously for `R_total`.

H3 — head-change gate dominates:

Supported analogously for `R_head`.

H4 — convergence is multi-criterion:

Supported if more than one ratio remains materially >1 in the terminal failed
states without one stable dominant gate.

## Stop rule

Close after criterion attribution.

Do not:

- change any tolerance;
- change MaxIt or MaxBackTr;
- change retry count;
- change temporal budget;
- change ELAS;
- implement a repair.

Any repair must target the identified criterion/mechanism in a separate
preregistered workunit.
