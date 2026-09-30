# F-PE-ELASTIC60 — independent-budget C-SAFE compatibility preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authorities:
- F-PE-ELASTIC54 — frozen global scaling alpha = 0.17320259355765216;
- F-PE-ELASTIC57 — qualified refine-only C-SAFE controller pattern;
- F-PE-ELASTIC58R — independent Reference-only mode-7 head budgets.

Parent postimage:
`research/f-pe-elastic58r-mode7-reference-budget-requalification@9ac65587fe404511410abf407fc3bebcbb798c85`

Canonical dependency:
`integration/f-ci-canonical@656ddea918c58267a08c2b626d498c998daccc60`
with F-PE-ELASTIC59 admitted.

## Question

Can the previously qualified mode-7 defect indicator and frozen global scaling
drive the refine-only C-SAFE pattern against an independently calibrated
Reference head-error budget without false acceptance?

## Frozen scientific authority

Global scaling:
`alpha = 0.17320259355765216`.

Independent mode-7 head budgets from ELASTIC58R:
- Se=0.65: `4.6839388616604083e-6 cm`;
- Se=0.85: `8.1523527498461590e-5 cm`;
- Se=0.98: `1.9893113165281307e-3 cm`.

No alpha or budget may be refit in ELASTIC60.

## Physical domain

Use exactly the ELASTIC58R E0 domain:
- materials B01, B12, O01, O05, O14, O18;
- Se = 0.65, 0.85, 0.98;
- DRYING, NOMINAL, WETTING forcing perturbations around free-drainage equilibrium;
- 16 homogeneous cells x 10 cm;
- bottom mode 7;
- swkimpl=0;
- ELAS OFF;
- zero distributed source/sink.

## Candidate dt ladder

Controller tries dt from coarse to fine:

`0.0256, 0.0128, 0.0064, 0.0032, 0.0016 day`.

This is the reverse of the preregistered ELASTIC58R calibration ladder and
introduces no new dt value.

## Controller decision

For each of the 54 physical cases and each candidate dt:

1. run one Reference full solve;
2. require converged accepted full solve;
3. require typed integrated mass residual available and <= 1e-12 cm;
4. evaluate the research mode-7 defect indicator with previous right derivative
   fixed to zero, corresponding to the initial equilibrium predecessor;
5. require finite available Binf;
6. compute `H_bound = alpha * Binf`;
7. accept the **first** candidate in descending-dt order satisfying
   `H_bound <= H_budget(Se)`;
8. otherwise refine to the next smaller dt.

No interpolation between Se budgets.
No step enlargement.
No use of observed two-half error in the controller decision.

If no candidate passes:
`EXHAUSTED`.

## Independent validation oracle

After the controller decision only:

- use the already executed full-versus-two-half Reference pair at the accepted
  dt when full, half1 and half2 all converge;
- validate `H_INF <= H_budget(Se)`.

If the controller accepts but the two-half oracle is unavailable:
`ORACLE_UNAVAILABLE_ACCEPT`,
which is a qualification blocker, not a pass.

If observed H_INF exceeds the frozen budget:
`FALSE_ACCEPT`.

## Hypotheses

H1. C-SAFE produces no FALSE_ACCEPT across the 54-case domain.

H2. Every controller acceptance has a valid independent two-half oracle.

H3. At least one case is accepted before the smallest dt, establishing that the
controller is not equivalent to unconditional minimum-dt execution.

H4. The controller may legitimately exhaust cases; exhaustion is safe and is
not a false acceptance.

## Gates

A1. Exact 54-case domain and exact five-dt ladder.

A2. O0/O2 semantic identity.

A3. Controller decisions use only full-solve/mass/Binf/alpha/budget data.

A4. Frozen alpha and ELASTIC58R budgets are exact constants.

A5. Zero FALSE_ACCEPT.

A6. Zero ORACLE_UNAVAILABLE_ACCEPT.

A7. Every accepted pair satisfies the independent budget.

A8. Zero production `src/**` changes.

## Decision

A green result qualifies only:

`INDEPENDENT_BUDGET_COMPATIBLE_CSAFE_RESEARCH_PATTERN`.

It does not admit the mode-7 defect indicator or controller to production.
Production integration, cost and full F-CI14 multi-metric acceptance remain
separate work.
