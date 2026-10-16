# F-PE-TEMPORAL05 closeout — blinded temporal accuracy/performance Pareto frontier

Date: 2026-09-26

Status: `CLOSED_BLIND_VALIDATED_C0P65_NO_PRODUCTION_ADMISSION`

## Question

Is there a history-aware coefficient between the accurate-but-slow half-history policy and the direct-accept regime that improves retry cost without weakening the fixed oracle-error envelope?

## Calibration

Policy family:

`budget(c) = max(1e-5 cm, c * dt * ||h_dot_previous||_inf)`.

Calibration coefficients 0.50 through 0.90 were evaluated on 24 calibration points.

The preregistered deterministic selection rule chose:

`c = 0.65`

because:

- it completed 24/24;
- it satisfied the unchanged physical envelope;
- it reduced retries from 24 at c=0.50 to 8;
- c=0.70 had the same retry count and therefore lost the smaller-coefficient tie-break;
- c>=0.75 removed all retries but exceeded the fixed dtheta bound.

## Blind holdout

The frozen c=0.65 coefficient was then evaluated without modification on 24 held-out difficult points.

Result:

- 24/24 complete;
- all physical oracle-error bounds pass;
- mass accounting complete;
- retries reduced from 24 to 16 versus c=0.50;
- no solver rejections;
- median repeated-trial runtime ratio = 0.99188 versus c=0.50.

The aggregate runtime gain is small because only one-third of holdout points change transaction path, but those path-changing cases show much larger local gains.

## Scientific conclusion

A history-aware coefficient of 0.65 is a blind-validated Pareto improvement over the natural c=0.50 defect scale on the tested dynamic-history domain.

It preserves the same strict oracle-error envelope while reducing temporal retry incidence.

It does not eliminate all retries, and its whole-matrix median runtime gain is therefore modest.

## Decision

TEMPORAL05 closes research-only.

No production temporal-budget change is admitted here.

No error bound was moved after observing results.

## Required successor

`F-PE-TEMPORAL06 — production-shaped c=0.65 coupling qualification`

The successor should:

- apply the frozen c=0.65 policy test-only to repeated same-origin corrector sequences and MODFLOW-facing coupling patterns;
- compare against current fixed policy and c=0.50 where meaningful;
- preserve refined-oracle physical error authority;
- quantify end-to-end runtime, retry incidence and mass behavior;
- only then open or perform a separate production admission step.
