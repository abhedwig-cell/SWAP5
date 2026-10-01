# PPA-WU05-C3R formula reconciliation matrix

Date: 2026-10-01

Legend:
- **PINNED-431**: formula/behavior directly visible in retained 4.3.1 source-bearing evidence.
- **FAMILY-CORROBORATED**: recovered public legacy source and 4.3.1 surrounding evidence agree on the implementation family, but the complete formula block is not visible in the retained 4.3.1 diff.
- **POLICY-REPLACED**: historical numerical policy intentionally replaced while preserving the source equation.
- **OPEN**: requires direct B1.11 trace/source comparison.

| Block | Status | Evidence / consequence |
|---|---|---|
| six oxygen precompute arrays | PINNED-431 | S11 pristine diff exposes names, construction role and current use |
| d_soil runtime expression | PINNED-431 | exact expression visible in 4.3.1 diff context |
| waterfilm call contract | PINNED-431 | exact call and immutable cache inputs visible |
| waterfilm MvG integrand | FAMILY-CORROBORATED | optimization header in 4.3.1 context describes same simplified MvG capacity algebra; full FUNC body absent from retained diff |
| duplicate QROMBD removal | PINNED-431 experimental | September controlled 4.3.1 performance evidence |
| WFT300 | experimental approximation | qualified historically in 4.3.1 performance work; requires SWAP5 requalification |
| temperature-dependent parameters | FAMILY-CORROBORATED | full block recovered from public legacy family; absent from retained 4.3.1 diff hunks |
| microbial_resp | FAMILY-CORROBORATED | same |
| MICRO | FAMILY-CORROBORATED | same |
| MACRO low-demand analytical branch | FAMILY-CORROBORATED | same family; not directly shown in retained 4.3.1 hunks |
| MACRO zero-depth equation derivative | PINNED-431 | SWAP-007 patch exposes exact derivative and Newton quotient |
| MACRO Newton/restart policy | POLICY-REPLACED | source equation proven monotone and uniquely bracketable; bounded candidate used |
| outer residual c_macro-c_min_micro | PINNED-431 experimental | recovered exact fast-no-stress patch and legacy SOLVE semantics |
| outer ZBREND/Newton execution policy | POLICY-REPLACED | bounded monotone candidate; physical parity still required |
| rwu_factor mapping | FAMILY-CORROBORATED | recovered legacy family; must be traced against B1.11 |
| saturated shortcut | FAMILY-CORROBORATED | recovered legacy family; B1.11 trace required |
| max_resp_factor==1 special case | FAMILY-CORROBORATED | recovered legacy family; B1.11 trace required |
| SWSOPHY=1 tabular waterfilm | OPEN | intentionally excluded from analytical-MvG C3Q first gate |

## Consequence

The analytical-MvG reconstruction is source-complete enough for execution, but not all formula blocks are pinned to B1.11 source text. Therefore C3Q trace parity is not optional: it is the mechanism that promotes FAMILY-CORROBORATED blocks to qualified 4.3.1 behavior without inventing source identity.

No additional user upload is a prerequisite for continuing this reconciliation.
