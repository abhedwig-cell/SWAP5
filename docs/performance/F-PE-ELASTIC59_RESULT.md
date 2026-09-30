# F-PE-ELASTIC59 — external physical head-budget normalization result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic59-external-budget-normalization`

Qualified postimage:
`d1cb04ec2472effeb0199fb38ce77b5de40c193a`

Canonical baseline:
`integration/f-ci-canonical@656ddea918c58267a08c2b626d498c998daccc60`

Workflow run:
`36692104374`

Job:
`109811463728`

Conclusion:
SUCCESS.

## Question

Can an externally supplied physical temporal head-error budget be mapped
fail-closed onto the qualified conservative mode-7 defect indicator without
inventing a SWAP default?

## Frozen relation

ELASTIC54/55 qualified the research envelope:

`H_realized <= alpha * Binf`

with

`alpha = 0.17320259355765216`.

ELASTIC59 therefore defines, for an externally qualified physical temporal head
budget `H_budget > 0`:

`C_phys = alpha * Binf / H_budget`.

Candidate acceptance:

`C_phys <= 1`.

Equivalent indicator-space budget:

`B_budget = H_budget / alpha`.

No application budget is selected by ELASTIC59.

## Governance

This construction matches canonical accuracy ownership:

- application head accuracy is externally qualified;
- temporal allocation is externally qualified;
- the resulting physical temporal head budget is application-owned;
- SWAP does not invent a universal numeric default.

HYDRO-MEMORY Stage 0, for example, has its own separately governed head budget,
but ELASTIC59 does not reuse that value as a general mode-7 default.

## Qualification probes

Synthetic positive probe budgets:

- 0.01 cm;
- 0.1 cm;
- 1.0 cm.

These are algebraic qualification probes only.

Invalid probes:
- zero;
- negative;
- +Inf;
- NaN.

Invalid budget/indicator input fails closed.

## Multi-profile replay

The full four-profile ELASTIC58 bank was replayed with:
- frozen profile/material selection;
- frozen mode-7 research indicator;
- frozen alpha;
- no tolerance refit;
- O0/O2 semantic identity.

Aggregate controller-normalization observations:

### 0.01 cm probe

- accepted sequences: `96`;
- paired accepted observations: `90`;
- exhausted: `96`;
- paired false accepts: `0`.

### 0.1 cm probe

- accepted sequences: `158`;
- paired accepted observations: `131`;
- exhausted: `34`;
- paired false accepts: `0`.

### 1.0 cm probe

- accepted sequences: `160`;
- paired accepted observations: `149`;
- exhausted: `32`;
- paired false accepts: `0`.

Across all probes:

- accepted: `414`;
- paired accepted: `370`;
- false accepts: `0`.

## Algebra qualification

For every finite positive Binf/budget pair, qualification verified exact
classification equivalence between:

`alpha * Binf / H_budget <= 1`

and

`Binf <= H_budget / alpha`.

No empirical multiplier other than the frozen alpha was introduced.

## Envelope implication

For every paired accepted observation:

`H_realized <= alpha * Binf <= H_budget`.

No paired observation violated its active synthetic physical budget.

This is the key safety property of the bridge.

## Fail-closed semantics

The normalization returns unavailable/fail-closed for:
- nonpositive budget;
- nonfinite budget;
- negative or nonfinite indicator.

There is:
- no clamp;
- no absolute-value rescue;
- no floor;
- no fallback default.

## Decision

Classification:

`QUALIFIED_EXTERNAL_PHYSICAL_BUDGET_TO_MODE7_INDICATOR_NORMALIZATION`.

ELASTIC59 qualifies only the research algebra and fail-closed semantics.

It does not qualify:
- any numeric application budget;
- a universal SWAP temporal default;
- production mode-7 indicator binding;
- production controller integration.

The remaining path to production is now structurally separated:

1. production-admit the already qualified mode-7, swkimpl=0 defect-indicator
   envelope;
2. bind only externally qualified physical head budgets through the frozen
   alpha normalization;
3. use the ELASTIC57 nonmonotonicity-robust refinement pattern;
4. preserve hard mass acceptance as an independent gate.
