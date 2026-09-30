# F-PE-ELASTIC58 — physical temporal-budget identifiability result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT_WITH_GOVERNANCE_BLOCKER

Branch:
`research/f-pe-elastic58-budget-identifiability`

Qualified postimage:
`8761d8321e8635f1f469d411bf35ba7c0a728c62`

Canonical baseline:
`integration/f-ci-canonical@6d7687900551e3bcd2497972acf002423ed9171c`

Workflow run:
`36705540115`

Job:
`109854790087`

Conclusion:
SUCCESS.

## Question

Can one unique physical temporal head budget be identified from the qualified
numerical evidence alone?

## Canonical authority

Canonical F-CI14 still states:

`profile_status = UNQUALIFIED_NO_NUMERIC_LIMITS`.

Every numerical endpoint acceptance limit remains null.

Therefore canonical contains no independently qualified physical head-error
criterion capable of choosing a production temporal budget.

## Frozen decision surface

ELASTIC58 replayed the complete four-profile ELASTIC55-57 bank with:

- frozen mode-7 research defect indicator;
- frozen global scaling
  `alpha = 0.17320259355765216`;
- unchanged C-SAFE controller semantics;
- no production source changes.

For every available point:

`E = alpha * Binf`.

All distinct positive E values were used as exact decision breakpoints.

Results:

- available indicator points: `1089`;
- physical sequences: `192`;
- distinct positive breakpoints: `651`;
- positive budget decision regions: `652`;
- distinct controller decision signatures: `600`;
- explored representative budget range:
  approximately `9.62e-6 ... 193.28 cm`.

The 16 sequences with no full-converged indicator point were retained explicitly
and remain EXHAUSTED for every possible budget.

## Representative trade-off points

The surface is broad and continuous rather than selecting one intrinsic
operating point.

Examples:

### Very strict region

Budget approximately `9.62e-6 cm`:
- accepted: `0 / 192`;
- exhausted: `192 / 192`.

### Budget approximately 0.00653 cm

- accepted: `90`;
- exhausted: `102`;
- paired accepted: `87`;
- median realized H_INF: approximately `8.88e-5 cm`;
- 95th percentile H_INF: approximately `2.18e-4 cm`;
- maximum paired H_INF: approximately `5.78e-4 cm`.

### Budget approximately 0.0678 cm

- accepted: `155`;
- exhausted: `37`;
- paired accepted: `121`;
- median realized H_INF: approximately `0.00329 cm`;
- 95th percentile: approximately `0.0209 cm`;
- maximum: approximately `0.0224 cm`.

### Budget approximately 0.435 cm

- accepted: `160`;
- exhausted: `32`;
- paired accepted: `146`;
- median realized H_INF: approximately `0.00776 cm`;
- 95th percentile: approximately `0.0384 cm`;
- maximum: approximately `0.0384 cm`.

### Very permissive region

Budget approximately `94.7 cm`:
- accepted: `176`;
- exhausted: `16`;
- paired accepted: `158`;
- maximum paired realized H_INF: approximately `0.294 cm`.

Increasing the budget further does not recover the 16 sequences that have no
available full-solve indicator point.

## Envelope preservation

Every paired accepted point continued to satisfy:

`H_INF <= alpha * Binf`.

The global scaling was not refitted.

Thus the numerical evidence provides a family of conservative operating points,
not a unique physical budget.

## Identifiability result

A unique production head budget is not identifiable from the current numerical
evidence alone.

The reason is structural:

- 652 valid budget regions exist;
- 600 produce distinct controller decisions;
- all are numerically interpretable;
- the repository provides no independent physical loss/accuracy criterion that
  ranks one region as the correct production choice.

Acceptance rate, retry work and realized endpoint error are consequences of a
chosen budget. They do not define what physical error is acceptable.

Selecting a budget from those trade-offs would therefore be a governance/model-
purpose decision, not a numerical derivation.

Qualification marker:

`F_PE_ELASTIC58_IDENTIFIABILITY=NOT_IDENTIFIED`.

## What is and is not blocked

Blocked:
- freezing a production temporal head budget;
- production admission of C-SAFE with a concrete accuracy threshold;
- claiming one point on the decision surface as scientifically preferred.

Not blocked:
- measuring the runtime cost of the mode-7 defect certificate;
- qualifying production-shaped certificate plumbing while retaining fail-closed
  no-budget semantics;
- preserving hard mass acceptance;
- further physical-error studies if an application-level accuracy target is
  supplied later.

## Decision

Classification:

`QUALIFIED_PHYSICAL_TEMPORAL_BUDGET_NON_IDENTIFIABILITY`.

This is a real governance blocker for numeric production temporal acceptance.

The next autonomous work should therefore move to the orthogonal unresolved
question that does not require choosing a budget:

measure the end-to-end runtime cost of the one-extra-tridiagonal mode-7 defect
certificate, including whether solver-work savings from ELAS dominate that
certificate overhead.
