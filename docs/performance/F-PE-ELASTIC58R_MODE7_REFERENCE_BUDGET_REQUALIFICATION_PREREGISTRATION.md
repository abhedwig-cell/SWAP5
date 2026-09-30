# F-PE-ELASTIC58R — mode-7 Reference head-budget requalification preregistration

Date: 2026-09-30

Status: PREREGISTERED_REQUALIFICATION

Parent authorities:
- F-PE-ELASTIC58 — QUALIFIED_MODE7_TYPED_MASS_PUBLICATION_BLOCKER;
- F-PE-ELASTIC59 — canonically admitted typed mass publication at `656ddea918c58267a08c2b626d498c998daccc60`.

Canonical baseline:
`integration/f-ci-canonical@656ddea918c58267a08c2b626d498c998daccc60`.

## Purpose

Replay the ELASTIC58 Reference-only mode-7 head-budget calibration without
changing its scientific design.

The only dependency change since ELASTIC58 is the canonically admitted
ELASTIC59 typed mass-publication seam required by the ELASTIC58 validity gate.

## Frozen design

Exactly preserve ELASTIC58:
- Reference solver only;
- materials B01, B12, O01, O05, O14, O18;
- Se = 0.65, 0.85, 0.98;
- DRYING/NOMINAL/WETTING forcing factors;
- bottom mode 7, swkimpl=0;
- five coarse dt candidates 0.0016, 0.0032, 0.0064, 0.0128, 0.0256 day;
- all 54 physical cases at every dt;
- full versus two-half construction;
- smallest candidate dt with 54/54 validity;
- exact-stratum head budget = empirical maximum U_h_inf over 18 cases;
- no indicator, alpha or controller execution.

No post-hoc case removal, tolerance change, new dt level or threshold factor is
allowed.

## Gates

A1. ELASTIC59 canonical admission is an ancestor of this workunit.
A2. Exact 270 pair matrix executes.
A3. O0/O2 identity.
A4. If a common domain exists, selection follows the frozen ELASTIC58 rule.
A5. All 54 cases remain in the selected dataset.
A6. Per-Se head budgets are exact empirical maxima.
A7. Indicator/controller firewall remains intact.
A8. Zero production source changes.

## Decision

A positive result qualifies a Reference-only mode-7 head-budget research
authority. A blocked result remains valid evidence.

No production temporal policy is admitted by ELASTIC58R.
