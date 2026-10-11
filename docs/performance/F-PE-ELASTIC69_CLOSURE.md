# F-PE-ELASTIC69 — post-admission closure

Date: 2026-09-30

Status: CLOSED_PRODUCTION_APPLICATION_POLICY_ADMITTED

Canonical admission:
`integration/f-ci-canonical@1c44aadb1bd177b5ff1bc975971479044f455719`

Merged PR:
`#900 — F-PE-ELASTIC69: admit bounded GENERATED mode7 0.20 cm application policy`

Qualified research authority:
- branch: `research/f-pe-elastic68-practical-budget-scan`;
- result commit: `05f8cd7ed4a3e95b9c7c4c78cdb39f7e61fa1bb5`;
- workflow run: `36728946761`;
- job: `109933079466`;
- conclusion: SUCCESS.

Admission gate:
- work head: `a6c777b92301a15da966a670c9060426b7e3db1a`;
- ELASTIC69 pull-request gate: SUCCESS;
- Documentation gate: SUCCESS;
- source delta relative to canonical: empty.

## Canonically admitted application policy

The following bounded application policy is admitted:

`GENERATED ELAS + bottom_mode=7 + swkimpl=0 + admitted temporal history + explicit caller-owned head budget = 0.20 cm`.

The value is application-owned. It is not a generic SWAP numerical default.

## Evidence basis

On the frozen four-profile GENERATED ELAS bank:

- 0.01 cm: 32/64 accepted origins, 334 rejected coarser levels;
- 0.20 cm: 64/64 accepted origins, 69 rejected coarser levels;
- observed maximum local full-vs-two-half head discrepancy at 0.20 cm:
  `0.03844542126583406 cm`;
- observed maximum local full-vs-two-half theta discrepancy:
  `6.143772462302577e-5`.

The 0.20-cm arm therefore materially reduces temporal refinement work in this
bounded application scope while remaining inside the preregistered practical
screen.

## Composition authority

No new production mechanism was added.

The admitted policy composes:

1. the canonically admitted generated soil-parameter-driven ELAS application
   chain through ELASTIC44/45;
2. the canonically admitted ELASTIC65 mode-7 explicit caller-owned head-budget
   interface and mass-first C-SAFE refine/recheck path.

## Preserved boundaries

Unchanged:

- Richards physics;
- ELAS parameterization;
- frozen alpha `0.17320259355765216`;
- hard physical mass acceptance;
- solver compartment and total-balance tolerances;
- retry semantics;
- reference mode availability;
- swkimpl=1 exclusion.

Not implied:

- universal SWAP default;
- OFF or FIXED_1E6 ELAS policy;
- arbitrary optional-process composition;
- complete F-CI14 eight-metric qualification;
- evidence for budgets above 0.20 cm.

## Closure

F-PE-ELASTIC69 is closed.

The ELAS / mode-7 physical temporal-budget line no longer requires additional
oracle completion or broader budget scanning for this application-policy
decision.

Future work should only reopen this value if application-level evidence from
the intended MultiSWAP/MODFLOW operating regime shows a material accuracy,
mass-conservation or performance reason to do so.
