# F-PE-ELASTIC60 — saturated feasibility-gap attribution result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic60-saturated-feasibility-gap`

Qualified postimage:
`5c1325266f389c96387ea1ad323c60e4d0236900`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36680964379`

Job:
`109776096104`

Conclusion:
SUCCESS.

## Question

Why do all saturated ELASTIC59 sequences exhaust under the inherited physical
head limit `0.01 cm` when controlled by `HCAND <= 0.01 cm`?

## Frozen bank

Exactly the saturated half of the ELASTIC59 multi-profile bank was replayed:
- profiles 11060, 10260, 8016, 3030;
- h0 = +2 and +10 cm;
- perturbations +/-0.035 and +/-0.05 cm/day;
- OFF, FIXED_1E6 and GENERATED;
- nine-step dt ladder.

Total:
- saturated sequences: `96`;
- requested points: `864`;
- O0/O2 semantic identity: PASS;
- zero production source changes.

## Classification

Per preregistration:

### ORACLE_INFEASIBLE

No paired-converged point in the frozen ladder achieves:

`H_INF <= 0.01 cm`.

### BOUND_OVERCONSERVATIVE

At least one paired-converged point achieves:

`H_INF <= 0.01 cm`

but no full-converged point achieves:

`HCAND <= 0.01 cm`.

### BOUND_REACHABLE

At least one full-converged point achieves:

`HCAND <= 0.01 cm`.

## Primary result

Across all 96 saturated sequences:

- ORACLE_INFEASIBLE: `61`;
- BOUND_OVERCONSERVATIVE: `35`;
- BOUND_REACHABLE: `0`.

Therefore saturated exhaustion has two distinct causes.

About 64% of sequences are not physically demonstrated below the inherited
0.01-cm head limit anywhere in the frozen paired ladder.

About 36% are physically feasible under the paired oracle but are rejected
solely because HCAND remains too conservative.

## Regime attribution

### OFF

- ORACLE_INFEASIBLE: `30 / 32`;
- BOUND_OVERCONSERVATIVE: `2 / 32`;
- BOUND_REACHABLE: `0`.

OFF is therefore overwhelmingly limited by paired solver/trajectory feasibility
rather than HCAND conservatism.

### FIXED_1E6

- ORACLE_INFEASIBLE: `10 / 32`;
- BOUND_OVERCONSERVATIVE: `22 / 32`;
- BOUND_REACHABLE: `0`.

This is the strongest overconservatism signal.

Most FIXED_1E6 saturated sequences already contain at least one paired point
below 0.01 cm but HCAND rejects the entire ladder.

### GENERATED

- ORACLE_INFEASIBLE: `21 / 32`;
- BOUND_OVERCONSERVATIVE: `11 / 32`;
- BOUND_REACHABLE: `0`.

GENERATED is mixed: both true paired-ladder infeasibility and bound
overconservatism matter.

## State attribution

### h0 = +2 cm

- ORACLE_INFEASIBLE: `33 / 48`;
- BOUND_OVERCONSERVATIVE: `15 / 48`.

### h0 = +10 cm

- ORACLE_INFEASIBLE: `28 / 48`;
- BOUND_OVERCONSERVATIVE: `20 / 48`.

The stronger saturated state has a somewhat larger overconservative fraction.

## Forcing attribution

### delta = -0.035 cm/day

- ORACLE_INFEASIBLE: 12;
- BOUND_OVERCONSERVATIVE: 12.

### delta = -0.05 cm/day

- ORACLE_INFEASIBLE: 16;
- BOUND_OVERCONSERVATIVE: 8.

### delta = +0.035 cm/day

- ORACLE_INFEASIBLE: 14;
- BOUND_OVERCONSERVATIVE: 10.

### delta = +0.05 cm/day

- ORACLE_INFEASIBLE: 19;
- BOUND_OVERCONSERVATIVE: 5.

Larger perturbation magnitude shifts the balance toward true paired-ladder
infeasibility.

## Interpretation

ELASTIC60 resolves the ambiguity left by ELASTIC59.

The saturated failure is not solely an indicator problem and not solely a
solver/dt-domain problem.

Both are real.

For OFF:
- the dominant issue is paired solvability / actual temporal error in the
  tested ladder.

For FIXED_1E6:
- the dominant issue is indicator conservatism.

For GENERATED:
- both mechanisms contribute materially.

The global inherited 0.01-cm head limit is therefore not itself falsified.

Instead, the route from temporal defect to a practical saturated acceptance
certificate remains too conservative for 35 sequences, while 61 sequences
would still need a broader successful paired reference domain even with a
perfect bound.

## Hypothesis outcome

A material fraction of saturated sequences is BOUND_OVERCONSERVATIVE:
SUPPORTED, `35/96`.

GENERATED and FIXED_1E6 differ:
SUPPORTED.

OFF contains more ORACLE_INFEASIBLE cases:
SUPPORTED, `30/32`.

## Decision

Classification:

`QUALIFIED_MIXED_SATURATED_FEASIBILITY_AND_BOUND_CONSERVATISM`.

No production admission is authorized.

The next bounded bound-design workunit may legitimately target the 35
BOUND_OVERCONSERVATIVE sequences without pretending to solve the 61
ORACLE_INFEASIBLE sequences.

A natural no-fit candidate is the direct defect correction:

`DINF = max |delta|`

rather than

`HCAND = min(max|e_raw|, 2*max|delta|)`.

That candidate must first be falsified against all paired multi-profile points
before any budget claim is made.
