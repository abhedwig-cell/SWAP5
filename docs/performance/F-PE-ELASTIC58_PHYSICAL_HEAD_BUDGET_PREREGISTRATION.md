# F-PE-ELASTIC58 — physical head-budget candidate qualification preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC57 — QUALIFIED_NONMONOTONICITY_ROBUST_REFINEMENT_CONTROLLER_PATTERN`

Parent postimage:
`research/f-pe-elastic57-controller-robustness@b09ab27c7e5cd1027975f42ad61511500e180d53`

Canonical authority:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Independent physical authority

Reuse the already frozen TEMPORAL04/05 physical oracle-error envelope.

Relevant endpoint limits:
- terminal pressure-head error <= `0.01 cm`;
- terminal volumetric water-content error <= `1e-5`;
- relative terminal bottom-flux error <= `1%`;
- relative integrated bottom-exchange error <= `0.5%`;
- complete mass accounting.

ELASTIC58 does not move these limits.

## Frozen mode-7 research authority

From ELASTIC54/55:
- `alpha_global = 0.17320259355765216`;
- observed holdouts satisfied
  `H_INF <= alpha_global * Binf`;
- alpha remains frozen.

Therefore the conservative Binf threshold implied solely by the independent
head limit is:

`Binf_budget = 0.01 / alpha_global = 0.05773585599727987 cm`.

This value is derived before ELASTIC58 results and is not fitted to the bank.

## Question

Does the derived mode-7 conservative head-budget candidate produce a safe
research acceptance subset over the full four-profile ELASTIC55/56 bank?

## Frozen replay bank

Reuse exactly:
- profiles 11060, 10260, 8016, 3030;
- same retention/geometric/generated-Ss materialization;
- same states, forcing, regimes and nine-dt ladder;
- same mode-7 research indicator;
- same O0/O2 checks;
- same hard solver and mass settings.

## Candidate acceptance rule

A full-solve point is research-head-eligible only when:
- full solve converged;
- mode-7 Binf is available;
- `Binf <= 0.05773585599727987 cm`.

For paired-converged points additionally verify:
- observed full-versus-two-half `H_INF <= 0.01 cm`;
- observed full-versus-two-half `THETA_INF <= 1e-5`.

No acceptance claim is made for unpaired points beyond the conservative
Binf-derived head bound.

## Controller replay

Apply the ELASTIC57 C-SAFE pattern:
- traverse largest to smallest dt;
- unavailable or over-budget -> refine;
- first eligible Binf -> select;
- no eligible point -> EXHAUSTED.

No monotonicity assumption.

## Gates

A1. Four parent profiles reproduce exactly.

A2. Same physical case bank and O0/O2 semantic identity.

A3. Frozen alpha is unchanged.

A4. Binf budget is exactly the derived constant
`0.05773585599727987 cm`.

A5. Every paired selected point satisfies `H_INF <= 0.01 cm`.

A6. Every paired selected point satisfies `THETA_INF <= 1e-5`.

A7. No selected point has unavailable Binf or Binf above the frozen threshold.

A8. Report selected versus EXHAUSTED counts by profile/regime.

A9. Zero `src/**` production changes.

## Non-claims

ELASTIC58 does not independently requalify TEMPORAL04/05 flux or integrated
exchange limits on this mode-7 bank, because the current ELASTIC55 replay does
not materialize the required refined-oracle bottom-flux/exchange observables.

Therefore even a green ELASTIC58 remains research-only and cannot by itself
admit a production temporal profile under F-CI14.

## Decision

A green result qualifies only:

`MODE7_HEAD_BUDGET_RESEARCH_CANDIDATE_DERIVED_FROM_EXISTING_PHYSICAL_LIMIT`.

A production admission successor would still require:
- independent refined-oracle flux/exchange qualification on the mode-7 bank;
- hard mass preservation;
- production indicator integration;
- transaction-policy integration.
