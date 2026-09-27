# F-PE-TEMPORAL10 result — demand-directed temporal constitutive qualification

Date: 2026-09-28

Status: `QUALIFIED_FOR_PRODUCTION_REPAIR`

PR:
`#697 — F-PE-TEMPORAL10: qualification evidence`

Workflow run:
`36355854803`

Measured head:
`9b6d330dc7b39176875dbbd10312f1df887454fd`

## Paired results

### N=1,000
- worker=1: 1.0313x
- worker=4: 1.0462x

### N=10,000
- worker=1: 1.0283x
- worker=4: 1.0503x

### N=40,000
- worker=1: 1.0521x
- worker=4: 1.0502x

All paired runs preserved exact q and response-tangent checksums.

## Decision

The candidate clears every frozen advancement gate:
- N=40,000 worker=4 >=1.05x: PASS;
- N=10,000 worker=4 >=1.03x: PASS;
- N=1,000 worker=4 <=2% regression: PASS;
- worker=1 no material regression: PASS.

Advance the exact same bounded source transformation to production repair:
- base state requests conductivity only;
- candidate state requests water content only;
- candidate state requests capacity only.

Before admission, add direct certificate-equivalence evidence. The existing FSI38 prescribed-qbot oracle already provides an independent default-MvG certificate oracle and no-extra-nonlinear-solve checks. Production qualification must run that authority against the patched source and add a direct-retention equivalence case.

No production source change was made by this qualification PR.
