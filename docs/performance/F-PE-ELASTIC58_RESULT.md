# F-PE-ELASTIC58 — physical head-budget candidate qualification result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT_WITH_SATURATED_EXHAUSTION

Branch:
`research/f-pe-elastic58-physical-head-budget`

Qualified postimage:
`badb2e6ddc3ebe51e46d1a9533986198a507383d`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36679675806`

Job:
`109772173586`

Conclusion:
SUCCESS.

## Question

Can the independently frozen TEMPORAL04/05 terminal-head limit
`0.01 cm` be converted into a safe research budget for the mode-7 defect
indicator by using the frozen ELASTIC54/55 conservative scaling?

## Frozen derivation

Independent physical head limit:

`H_limit = 0.01 cm`.

Frozen global scaling:

`alpha = 0.17320259355765216`.

Derived before the replay:

`Binf_budget = H_limit / alpha = 0.05773585599727987 cm`.

No bank result was used to choose this threshold.

## Frozen bank

The complete four-profile ELASTIC55/56 material bank was replayed:

- profiles 11060, 10260, 8016, 3030;
- states -75, -20, +2, +10 cm;
- perturbations +/-0.035 and +/-0.05 cm/day;
- OFF, FIXED_1E6 and GENERATED;
- nine-step dt ladder;
- mode-7, swkimpl=0 research defect indicator;
- C-SAFE refinement pattern.

Total controller sequences:
`192`.

## Primary result

C-SAFE selected a point satisfying the derived Binf budget in:

`96 / 192` sequences.

The remaining:

`96 / 192`

returned EXHAUSTED without false acceptance.

Among selected points:

- paired selected observations: `90`;
- paired head-limit failures: `0`;
- paired theta-limit failures: `0`;
- unavailable/over-budget selections: `0`.

Therefore the derived budget is safe on every paired selected observation in
the tested bank.

## Selected-state distribution

All selected sequences are unsaturated initial states:

- h0 = -75 cm: `48`;
- h0 = -20 cm: `48`;
- h0 = +2 cm: `0`;
- h0 = +10 cm: `0`.

Thus every tested saturated sequence exhausts the frozen dt ladder under this
derived head budget.

This is the central ELASTIC58 limitation.

## Regime distribution

Selected counts are exactly balanced:

- OFF: `32`;
- FIXED_1E6: `32`;
- GENERATED: `32`.

Per profile:

### profile 11060
- selected: 24;
- exhausted: 24;
- paired selected: 24.

### profile 10260
- selected: 24;
- exhausted: 24;
- paired selected: 24.

### profile 8016
- selected: 24;
- exhausted: 24;
- paired selected: 18.

### profile 3030
- selected: 24;
- exhausted: 24;
- paired selected: 24.

The saturated exhaustion is therefore not limited to one profile or ELAS
regime.

## Selected dt distribution

Among the 96 selected points:

- dt = 0.015625 day: 42;
- dt = 0.0078125 day: 18;
- dt = 0.001953125 day: 24;
- dt = 0.0009765625 day: 12.

No selected point required a smaller frozen dt.

## Paired physical margins

Worst directly observed paired selected endpoint differences:

- max H_INF = `5.776784369402321e-4 cm`;
- max THETA_INF = `1.1183733953368247e-6`.

Both are comfortably inside the inherited physical limits:

- H_INF <= 0.01 cm;
- THETA_INF <= 1e-5.

Largest selected Binf:

`0.04151882867811084 cm`

which remains below the derived threshold
`0.05773585599727987 cm`.

## Interpretation

ELASTIC58 establishes two different facts.

### Safety

The budget derivation is conservative on the observed selected subset.

It does not create false head or theta acceptance in any paired selected case.

The C-SAFE logic correctly returns EXHAUSTED where the budget cannot be met.

### Practicality

The candidate is too strict for the saturated mode-7 domain represented in the
bank.

All +2 cm and +10 cm sequences exhaust, including FIXED_1E6 and GENERATED.

This is consistent with ELASTIC53-55:
the mode-7 Binf bound can be orders of magnitude larger than the directly
observed full-versus-two-half endpoint head discrepancy, especially in
saturated states.

Therefore the frozen global alpha is safe but too conservative to turn the
independent 0.01-cm head criterion into a useful saturated production budget.

## Hypothesis outcome

Derived head budget is safe on selected paired observations:
SUPPORTED.

Theta limit is preserved on selected paired observations:
SUPPORTED.

Controller can fail safely when the budget is unreachable:
SUPPORTED.

Budget is practically usable across the saturated mode-7 domain:
FALSIFIED over the tested dt ladder.

## Production boundary

ELASTIC58 still does not requalify the TEMPORAL04/05 bottom-flux and integrated
exchange limits for this mode-7 bank.

It therefore cannot admit a complete F-CI14 numeric profile.

Even for head-only control, saturated practicality is unresolved.

## Decision

Classification:

`QUALIFIED_SAFE_UNSATURATED_HEAD_BUDGET_WITH_SATURATED_EXHAUSTION`.

No production admission is authorized.

The next bounded workunit should address the excessive saturated conservatism
without weakening the inherited 0.01-cm physical head limit.

The first research question should be whether a saturation-aware normalization
can be derived from the already observed elastic-storage / trajectory structure,
rather than fitted post hoc to endpoint errors.

Any successor must preserve:
- the frozen 0.01-cm head limit;
- hard mass acceptance;
- C-SAFE no-monotonicity-assumption logic;
- independent holdout testing.
