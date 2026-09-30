# F-PE-ELASTIC58R — mode-7 Reference head-budget requalification result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic58r-mode7-reference-budget-requalification`

Qualified postimage:
`3023dd6b65e63ee2ac3f30b87a96015c1c2dd9aa`

Canonical baseline:
`integration/f-ci-canonical@656ddea918c58267a08c2b626d498c998daccc60`

Dependency change since blocked ELASTIC58:
- F-PE-ELASTIC59 typed bottom-mode-7 mass publication canonically admitted.

Workflow run:
`36691812498`

Job:
`109810525785`

Conclusion:
SUCCESS.

## Purpose

Replay the scientific design of ELASTIC58 unchanged after admission of the
previously missing mode-7 typed mass-publication contract.

No defect indicator, ELASTIC54 alpha, C-SAFE controller, or production temporal
policy was used.

## Reference-only feasibility

All 54 physical cases were executed at all five preregistered coarse dt values:

| dt day | valid | invalid |
|---:|---:|---:|
| 0.0016 | 47 | 7 |
| 0.0032 | 54 | 0 |
| 0.0064 | 54 | 0 |
| 0.0128 | 50 | 4 |
| 0.0256 | 42 | 12 |

The prospective selection rule chooses the smallest candidate dt with 54/54
validity.

Selected common mode-7 Reference coarse dt:

`0.0032 day`.

Corresponding half-step:

`0.0016 day`.

The feasibility surface is non-monotone: validity is lower at both finer
0.0016 day and coarser 0.0128/0.0256 day levels.

## Independent Reference head budgets

At the selected common dt, all 54 physical cases were retained.

For each exact effective-saturation stratum, the empirical maximum
full-versus-two-half head-infinity disagreement was frozen.

### Se = 0.65

`H_budget = 4.6839388616604083e-6 cm`.

### Se = 0.85

`H_budget = 8.1523527498461590e-5 cm`.

### Se = 0.98

`H_budget = 1.9893113165281307e-3 cm`.

No multiplier was applied.

No application-resolution floor was added.

No interpolation between Se strata is admitted.

These values are empirical Reference self-disagreement envelopes for this exact
mode-7 E0 calibration domain. They are not universal SWAP accuracy tolerances.

## Firewall

Calibration output contains no:
- ELASTIC53 defect-indicator result;
- ELASTIC54 alpha;
- ELASTIC55/56 calibration result;
- ELASTIC57 controller result;
- Binf-based selection.

Thus the budget remains independent of the candidate temporal indicator and
controller.

## ELASTIC58 blocker resolution

Original ELASTIC58 produced 0/54 valid cases at every dt because accepted mode-7
Reference solves did not publish typed integrated/native mass residuals required
by the validity gate.

After ELASTIC59 admission:
- 54/54 validity is achieved at 0.0032 and 0.0064 day;
- the independent Reference dataset is available;
- the head budgets can be frozen without changing the ELASTIC58 design.

This confirms that the ELASTIC58 failure was a publication-contract blocker,
not a physical impossibility of the mode-7 calibration domain.

## Gates

- A1 ELASTIC59 canonical admission ancestor: PASS;
- A2 exact 270-pair matrix: PASS;
- A3 O0/O2 identity: PASS;
- A4 prospective common-dt selection: PASS;
- A5 all 54 cases retained: PASS;
- A6 exact empirical per-Se head-budget freeze: PASS;
- A7 indicator/controller firewall: PASS;
- A8 zero production source changes: PASS.

## Decision

Classification:

`QUALIFIED_REFERENCE_ONLY_MODE7_HEAD_BUDGET_RESEARCH_AUTHORITY`.

The next bounded workunit may independently test the mode-7 defect indicator and
C-SAFE controller against these frozen head budgets.

No production temporal-policy admission is authorized by ELASTIC58R alone.
