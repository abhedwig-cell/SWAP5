# F-PE-ELASTIC58 — independent mode-7 Reference head-budget calibration result

Date: 2026-09-30

Status: QUALIFIED_NEGATIVE_RESEARCH_RESULT

Branch:
`research/f-pe-elastic58-mode7-reference-budget`

Qualified postimage:
`faeeb6a327805bd7dff2111ef2300a93d9f93b6e`

Canonical baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36689528197`

Job:
`109803165898`

Conclusion:
SUCCESS.

## Question

Can an independent Reference-only head-error budget be calibrated for the
bottom-mode-7, swkimpl=0 free-drainage domain using the same prospective
common-dt methodology as PUB-P2E08/P2E09?

## Frozen calibration bank

Executed:
- 6 materials: B01, B12, O01, O05, O14, O18;
- Se = 0.65, 0.85, 0.98;
- three predeclared forcing perturbations around free-drainage equilibrium;
- 54 physical cases;
- five candidate coarse dt values;
- full plus two-half Reference trajectories;
- 270 physical-pair/dt combinations;
- O0/O2 identical;
- zero production source changes.

The defect indicator, ELASTIC54 alpha and C-SAFE controller were not used.

## Primary result

No common Reference calibration domain could be established.

For every preregistered dt:

| dt day | valid | invalid |
|---:|---:|---:|
| 0.0016 | 0 | 54 |
| 0.0032 | 0 | 54 |
| 0.0064 | 0 | 54 |
| 0.0128 | 0 | 54 |
| 0.0256 | 0 | 54 |

Classification:

`BLOCKED_MODE7_REFERENCE_COMMON_DOMAIN`.

No head-budget values were frozen.

## Failure-stage attribution

All 270 trials fail at the same gate:

`COARSE_REFERENCE_GATE`.

There are:
- no initialization failures;
- no material-lookup failures;
- no selected-dt postprocessing failures.

The uniformity rules out a normal dt-dependent solvability explanation as the
primary blocker.

## Canonical contract cause

Inspection of
`src/adapter/mod_reference_richards_legacy_binding.f90`
shows that typed Reference mass diagnostics are materialized only for:

- bottom mode 5;
- bottom mode 2.

For those modes the binding publishes:
- `native_balance_rate_residual_available = .true.`;
- `native_balance_rate_residual_cm_per_day`;
- `integrated_mass_balance_residual_available = .true.`;
- `integrated_mass_balance_residual_cm`.

No corresponding publication block exists for bottom mode 7.

Therefore a converged mode-7 solve cannot satisfy the preregistered Reference
validity contract that requires available typed integrated mass residuals.

This is a publication/contract blocker, not evidence that all mode-7 physical
solves are nonconvergent.

## Relation to earlier ELASTIC work

ELASTIC46-57 could study mode 7 because those workunits used direct solver state,
existing mass observations or transaction diagnostics appropriate to their
research questions.

ELASTIC58 deliberately raised the bar to the independent P2E08-style Reference
validity contract.

That contract exposes the missing mode-7 typed mass-publication seam.

## Hypothesis outcome

H1, common mode-7 Reference dt exists under the full typed validity contract:
NOT TESTABLE / BLOCKED by missing typed mass publication.

H2, Se-dependent head self-disagreement can be calibrated:
NOT REACHED.

H3, budget can be frozen independently of indicator/controller:
NOT REACHED.

## Decision

Classification:

`QUALIFIED_MODE7_TYPED_MASS_PUBLICATION_BLOCKER`.

No budget is admitted.

The next bounded workunit should qualify the missing bottom-mode-7 typed mass
publication contract in the Reference solver binding.

That work must:
- derive the mode-7 typed residual from the exact accepted HeadCalc residual
  authority;
- verify it against an independent physical interval ledger;
- preserve bottom-mode-2 and bottom-mode-5 semantics exactly;
- remain separate from temporal-budget calibration;
- avoid any temporal tolerance or controller change.

After that admission candidate is qualified, ELASTIC58 can be replayed without
changing its physical calibration design.
