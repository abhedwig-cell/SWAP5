# PPA-WU05-A28 admission candidate

Date: 2026-10-03
Status: QUALIFIED_ADMISSION_CANDIDATE
Candidate postimage: 769d1f4baaa929ff3f6986eaeadc4f2d946bf09e

## Claim

A28_V1 is an explicit opt-in approximate RFM sorptivity-panel policy. Exact fixed-64 remains the default/reference route.

Policy:
- h < -30 cm: 64 panels;
- -30 <= h < -3 cm: 32 panels;
- h >= -3 cm: 16 panels.

## Evidence chain

1. Original PERF07 generalization was falsified on the broadened 36-material catalog: max relative sorptivity error 4.595%.
2. A28_V1 broadened constitutive qualification: 36 Staringreeks materials x 17 pressure heads, max relative sorptivity error 0.709%.
3. Short exact-versus-approximate ABC qualification: 30 jointly completed C cases, negligible hydrologic drift, no E1 regression.
4. Q4 long-history: ten executable exact/approx pairs over 24 days / 20 cycles with negligible drift; trusted reconstruction/replay and candidate non-publication gates pass. Original H3 fixture was retained as falsified rather than tuned through.
5. Q4B-3: frozen exact fixture repeatedly crosses the -3 cm policy boundary (160 observed surface crossings over four cases). Frozen Stage B passes with zero observed exact/approx storage, bottom-outflow, theta and endpoint-water difference; max approximate mass residual 1.11e-14 cm.
6. Q4B-30: independently frozen dry exact fixture repeatedly crosses -30 cm (B01 40 crossings per geometry; O05 34 per geometry). Frozen Stage B passes with zero observed exact/approx storage, bottom-outflow, theta and endpoint-water difference; max approximate mass residual 1.11e-14 cm.

## Runtime finding discovered during qualification

F-TEMP-MODE3-01 is a separate SWAP5 runtime issue exposed by Q4B: bottom_mode=3 was unconditionally excluded from the external full/half temporal-error route, and ordinary BASE state used an identity-only fallback. The bounded repaired decomposition completed B01/O05 BASE and exact-RFM mode-3 cases in one attempt with zero temporal/solver/admission/mass rejections.

The dynamic-top provider-lifetime hypothesis was falsified. The observed long-run provider failure came from an invalid Q4B runoff fixture (active runoff with zero runoff resistance), not provider ownership. That hypothesis is not part of the admission claim.

## Admission boundary

Qualified here:
- explicit opt-in configuration semantics;
- broad catalog constitutive accuracy;
- short production trajectories;
- long stateful histories;
- accepted-state reconstruction/replay;
- repeated crossing of both A28_V1 panel-policy boundaries.

Not qualified here:
- canonical integration;
- portable speedup;
- MultiSWAP scaling;
- MODFLOW coupled stability/performance;
- Ribasim coupling;
- field validation.

## Decision

A28_V1 is ready to be treated as a production-admission candidate for the RFM component. The next admission gate is a representative MultiSWAP-MODFLOW workload comparing exact fixed-64 versus A28_V1 for runtime, water balance, coupled groundwater response and failure/retry behavior. No further panel-policy tuning is permitted before that comparison.
