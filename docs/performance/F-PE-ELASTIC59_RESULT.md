# F-PE-ELASTIC59 — 1 cm head-budget expanded holdout result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic59-head-budget-holdout`

Qualified postimage:
`5db2513714ce6ce6618d803a7fbf3ea241a07119`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36686903865`

Job:
`109794760869`

Conclusion:
SUCCESS.

## Question

Does the ELASTIC58 1.0-cm mode-7 model-certificate head-budget candidate
survive an independent expanded holdout with different source profiles, states
and forcing magnitudes?

Frozen global scaling:
`alpha = 0.17320259355765216`.

Primary candidate:
`1.0 cm`.

Frozen comparator:
`0.3 cm`.

## Independent holdout profiles

The preregistered selector excluded all previously used profile IDs and
soilunits and chose:

1. profile `11020`
   - soilunit `Zn10A`;
   - 2 horizons;
   - blocks `[104,204]`.

2. profile `8120`
   - soilunit `EZ50A`;
   - 3 horizons;
   - blocks `[101,101,201]`.

3. profile `4015`
   - soilunit `uHn21`;
   - 4 horizons;
   - blocks `[103,202,202,201]`.

4. profile `3011`
   - soilunit `Y21g`;
   - 5 horizons;
   - blocks `[102,202,202,202,205]`.

None overlaps the ELASTIC46-58 profile IDs or the ELASTIC55 soilunits.

## Expanded physical bank

New initial heads:
- -150 cm;
- -40 cm;
- -5 cm;
- +5 cm;
- +20 cm.

New perturbations:
- -0.07 cm/day;
- -0.02 cm/day;
- +0.02 cm/day;
- +0.07 cm/day.

Per profile:
- 5 states;
- 4 perturbations;
- 3 ELAS regimes;
- 9 dt values;
- 540 requested cases.

Total requested:
`2160` cases.

Qualification:
- all requested cases executed;
- O0/O2 semantic identity passed for every profile;
- no alpha refit;
- zero production `src/**` changes.

## Aggregate result

### 0.3-cm comparator

- accepted: `208 / 240`;
- exhausted: `32`;
- acceptance fraction: `0.866667`;
- paired accepted: `202`;
- mean attempted ladder points: `2.8625`;
- maximum paired H_INF: `0.0879245 cm`;
- maximum H_INF / budget: `0.293082`;
- maximum frozen-envelope utilization:
  `H_INF/(alpha*Binf) = 0.673426`.

### 1.0-cm candidate

- accepted: `208 / 240`;
- exhausted: `32`;
- acceptance fraction: `0.866667`;
- paired accepted: `206`;
- mean attempted ladder points: `2.41667`;
- maximum paired H_INF: `0.0879245 cm`;
- maximum H_INF / budget: `0.0879245`;
- maximum frozen-envelope utilization:
  `H_INF/(alpha*Binf) = 0.673426`.

Thus the 1.0-cm candidate has:
- identical acceptance count;
- identical exhaustion count;
- identical maximum observed paired endpoint error;
- more paired accepted observations;
- lower refinement effort.

This independently reproduces the ELASTIC58 plateau result.

## Per-profile result

All four profiles show the same acceptance count for 0.3 and 1.0 cm:

- 52 accepted;
- 8 exhausted.

The 1.0-cm candidate consistently lowers refinement effort.

### profile 11020

0.3 cm:
- mean retry index: `0.654`;
- mean attempts: `2.633`.

1.0 cm:
- mean retry index: `0.154`;
- mean attempts: `2.200`.

Maximum paired H_INF:
`0.0481546 cm`.

### profile 8120

0.3 cm:
- mean retry index: `1.000`;
- mean attempts: `2.933`.

1.0 cm:
- mean retry index: `0.462`;
- mean attempts: `2.467`.

Maximum paired H_INF:
`0.0592800 cm`.

### profile 4015

0.3 cm:
- mean retry index: `1.019`;
- mean attempts: `2.950`.

1.0 cm:
- mean retry index: `0.462`;
- mean attempts: `2.467`.

Maximum paired H_INF:
`0.0879245 cm`.

### profile 3011

0.3 cm:
- mean retry index: `1.000`;
- mean attempts: `2.933`.

1.0 cm:
- mean retry index: `0.538`;
- mean attempts: `2.533`.

Maximum paired H_INF:
`0.0627077 cm`.

## Regime/state structure

For both budgets:

- OFF accepted: `48`;
- FIXED_1E6 accepted: `80`;
- GENERATED accepted: `80`;
- unsaturated accepted: `144`;
- saturated accepted: `64`.

Therefore the larger 1.0-cm budget does not unlock additional sequences on
this independent holdout. It only reaches the same accepted set with fewer
refinements.

The remaining 32 exhausted sequences are not resolved by relaxing the
certificate from 0.3 to 1.0 cm and are therefore dominated by solver /
availability limitations rather than this budget range.

## Conservative-envelope preservation

Every paired accepted 1.0-cm observation satisfies:

`H_INF <= alpha*Binf <= 1.0 cm`.

No frozen-envelope failure occurred.

The worst observed envelope utilization is approximately `0.6734`, still
inside the ELASTIC54/55 global conservative relation.

## Hypothesis outcome

1.0-cm candidate survives independent expanded holdout:
SUPPORTED.

Frozen global scaling survives the expanded holdout:
SUPPORTED.

1.0 cm accepts at least as many sequences as 0.3 cm:
SUPPORTED, counts are identical.

1.0 cm lowers refinement effort without increasing observed maximum paired
endpoint error:
SUPPORTED on all four holdout profiles.

Need to loosen beyond 1.0 cm for active-ELAS reachability:
NOT SUPPORTED by this bank.

## Interpretation

ELASTIC58 identified a 0.3-1.0 cm numerical plateau.

ELASTIC59 confirms that plateau on:
- four new BRO profile/material structures;
- new unsaturated and saturated heads;
- new forcing magnitudes.

Within both banks, 1.0 cm is a stronger research candidate than 0.3 cm because
it reaches the same sequence set with less refinement and no observed increase
in maximum paired endpoint error.

This is still a numerical qualification, not an application-level declaration
that 1 cm pressure-head temporal error is universally acceptable.

## Decision

Classification:

`QUALIFIED_1CM_MODE7_HEAD_BUDGET_RESEARCH_CANDIDATE`.

No production admission is authorized by ELASTIC59.

The remaining path to production is now narrower:

1. production-shaped integration of:
   - mode-7 defect indicator;
   - frozen alpha;
   - 1.0-cm model temporal head budget;
   - C-SAFE refinement;
   while preserving hard mass acceptance;

2. end-to-end runtime and transaction qualification;

3. explicit acknowledgement that this qualifies only the model-certificate
   head-budget route and does not fill the complete eight-metric F-CI14
   endpoint-policy profile.
