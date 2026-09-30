# F-PE-ELASTIC58 — mode-7 head-budget frontier result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic58-head-budget-frontier`

Qualified postimage:
`e6bb42fb7f81329cd7c12f61d73ddba2222ac48f`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36686093785`

Job:
`109792193032`

Conclusion:
SUCCESS.

## Question

What acceptance/refinement/error frontier results when the qualified C-SAFE
controller pattern is evaluated over a fixed family of positive head budgets,
without selecting a production tolerance?

Frozen scaling:
`alpha = 0.17320259355765216`.

## Bank

The complete four-profile ELASTIC55-57 bank was replayed:

- profiles 11060, 10260, 8016, 3030;
- 192 profile/state/forcing/regime sequences;
- same nine-dt ladder;
- same mode-7 research indicator;
- same O0/O2 semantics;
- same frozen alpha;
- same C-SAFE refine-until-passing logic.

Budgets, fixed before results:

`0.01, 0.03, 0.1, 0.3, 1.0, 3.0, 10.0 cm`.

No production source changed.

## Frontier

| head budget cm | accepted / 192 | exhausted | mean attempted ladder points | paired accepted | max paired H_INF cm |
|---:|---:|---:|---:|---:|---:|
| 0.01 | 96 | 96 | 5.719 | 90 | 0.000578 |
| 0.03 | 128 | 64 | 4.849 | 103 | 0.014888 |
| 0.10 | 158 | 34 | 3.833 | 131 | 0.038445 |
| 0.30 | 160 | 32 | 3.193 | 139 | 0.038445 |
| 1.00 | 160 | 32 | 2.693 | 149 | 0.038445 |
| 3.00 | 166 | 26 | 2.271 | 152 | 0.107990 |
| 10.0 | 170 | 22 | 2.104 | 155 | 0.175967 |

Acceptance count is weakly monotone with increasing budget, as required.

## Accuracy-envelope behavior

For every paired accepted point:

`H_INF <= alpha * Binf <= budget`.

No false acceptance occurred.

The maximum observed utilization of the conservative global envelope
`H_INF / (alpha*Binf)`
was approximately `0.4421` across the characterized frontier.

The maximum observed realized-error fraction `H_INF / budget` was:

- 0.0578 at 0.01 cm;
- 0.496 at 0.03 cm;
- 0.384 at 0.10 cm;
- 0.128 at 0.30 cm;
- 0.0384 at 1.0 cm;
- 0.0360 at 3.0 cm;
- 0.0176 at 10 cm.

Thus the candidate certificate remains substantially conservative throughout
the tested budget family.

## Regime structure

At 0.01 cm:
- OFF accepted 32;
- FIXED_1E6 accepted 32;
- GENERATED accepted 32;
- all accepted sequences were unsaturated.

At 0.03 cm:
- OFF 32;
- FIXED_1E6 34;
- GENERATED 62.

At 0.10 cm:
- OFF 32;
- FIXED_1E6 62;
- GENERATED 64.

At 0.30 and 1.0 cm:
- OFF 32;
- FIXED_1E6 64;
- GENERATED 64.

The active-ELAS saturated bank therefore becomes almost fully reachable by
0.1-0.3 cm, whereas the remaining exhaustion is concentrated in OFF.

At 10 cm:
- OFF reaches 42;
- FIXED_1E6 and GENERATED remain 64 each.

The unresolved exhaustion at permissive budgets is therefore mostly a solver /
availability issue, not an error-budget issue.

## Numerical knee / plateau

The most informative feature of the frontier is the plateau between
`0.3 cm` and `1.0 cm`:

- accepted count is identical: `160/192`;
- exhausted count is identical: `32`;
- maximum paired realized H_INF is identical:
  `0.0384454 cm`;
- the 1.0-cm budget requires fewer attempted ladder points on average:
  `2.69` versus `3.19`.

The 0.1-cm point is also close:
- only two fewer accepted sequences than 0.3/1.0 cm;
- the same observed maximum paired H_INF;
- higher refinement effort.

Therefore the observed bank contains a broad numerical plateau rather than a
single sharply identified physical tolerance.

## Interpretation

ELASTIC58 does not justify choosing a production head budget from numerical
behavior alone.

It does establish:

1. very strict budgets below 0.03 cm cause large exhaustion/refinement cost;
2. most active-ELAS saturated sequences become reachable by 0.1-0.3 cm;
3. 0.3-1.0 cm forms an acceptance plateau in this bank;
4. budgets above 1 cm mainly recover additional OFF sequences while allowing
   larger realized endpoint errors;
5. the conservative envelope and C-SAFE correctness remain intact over the
   whole tested frontier.

The frontier therefore separates the numerical design problem from the
remaining physical/application decision.

## Hypothesis outcome

Safe ordered frontier:
SUPPORTED.

Frozen envelope preservation:
SUPPORTED.

Existence of a unique numerically determined physical head tolerance:
NOT SUPPORTED.

Existence of a broad numerical knee/plateau:
SUPPORTED around `0.1-1.0 cm`, strongest at `0.3-1.0 cm`.

## Decision

Classification:

`QUALIFIED_MODE7_HEAD_BUDGET_FRONTIER_WITHOUT_PHYSICAL_SELECTION`.

No production budget is selected.

A bounded next workunit may nominate `1.0 cm` as a **research candidate**
because, on this bank, it is not worse than 0.3 cm in acceptance or observed
paired error and requires less refinement.

That nomination must be subjected to an independent expanded holdout before it
can be considered a numeric policy candidate.

Even a successful head-budget qualification would still not by itself fill the
full eight-metric F-CI14 endpoint policy.
