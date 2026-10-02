# PPA-WU05-A28 production envelope — approximate RFM A28_V1

Date: 2026-10-02
Status: PRODUCTION_CANDIDATE_ENVELOPE_DEFINED
Default: EXACT
Approximate activation: EXPLICIT OPT-IN ONLY

## Qualified numerical envelope

A28_V1 may be considered only where the production RFM route and constitutive hydraulics remain within the model family exercised by A28.

Evidence:
- Q1/Q2: all 36 Staringreeks-2018 catalog materials, 17 pressure heads from -2000 to -1 cm; maximum sorptivity error 0.7087% versus fixed-64.
- Q3: 30 jointly completed short exact/approximate production-like C cases; no E1 regression and hydrologic differences orders of magnitude below gates.
- Q4: ten 24-day/20-cycle long-history exact/approximate pairs; negligible accumulated drift; trusted reconstruction/replay and candidate-discard immutability pass.
- Q4B: frozen O05 dynamic 64/32 threshold fixture in two geometries; 40 cycle-boundary pairs pass with max storage difference 1.48e-7 cm and max bottom-outflow difference 3.15e-7 cm.

A28_V1 policy is frozen:
- h < -30 cm: 64 panels;
- -30 <= h < -3 cm: 32 panels;
- h >= -3 cm: 16 panels.

## Explicit boundaries

The h >= -3 cm 16-panel branch has broad constitutive evidence but no long-history dynamic crossing in the production fixture. This is a coverage limitation, not an observed defect.

A28 does not establish:
- field accuracy of RFM itself;
- equivalence outside the qualified constitutive/model family;
- portable wall-clock speedup;
- MultiSWAP scaling efficiency;
- MODFLOW coupling stability;
- safety under unqualified RFM geometry/configuration combinations;
- canonical/default eligibility.

## Runtime contract

Production code must preserve:
1. EXACT as default.
2. A28_V1 only through explicit configuration.
3. 64 as the reference ceiling; any other ceiling with A28_V1 is invalid.
4. Unknown policy identifiers fail closed.
5. No automatic promotion from EXACT to A28_V1.
6. Policy name/version is emitted in run provenance.
7. Production statistics count evaluations in the 64, 32 and 16 panel bands so use outside observed dynamic coverage is visible.

Items 6-7 are required before large production admission; they are observability, not numerical-model changes.

## MultiSWAP-MODFLOW qualification

The next gate is system-level, not another single-column numerical sweep.

Run paired exact/A28 ensembles with identical initial states, forcing, groundwater coupling schedule and worker layout. Use a representative production subset large enough to exercise parallel scheduling but small enough that the exact arm remains affordable.

Minimum persisted comparisons:
- whole-system water balance;
- SWAP-MODFLOW exchange volume per coupling interval and cumulative;
- groundwater heads at coupling checkpoints;
- column storage and bottom flux distributions, including tails;
- failed/retried columns and nonlinear work;
- RFM panel-band occupancy;
- SWAP runtime, total coupled runtime and worker scaling;
- deterministic repeatability for a fixed worker configuration.

Initial admission gates:
- no approximate-only failed columns;
- no new mass-closure violation;
- cumulative coupled exchange difference <= 0.5% and no unexplained sign reversals;
- groundwater-head differences remain below the already accepted coupling tolerance of the selected production fixture; do not invent a new tolerance if the fixture has an existing one;
- distributional hydrologic differences remain small relative to the exact ensemble and are reported, not hidden behind only a mean;
- measurable positive end-to-end runtime benefit. If system runtime does not improve materially, A28 has no production rationale even if numerically acceptable.

Do not start at 100,000 columns. Qualify a stratified subset first, then scale only after numerical and coupling gates pass.

## Admission decision

A28_V1 is a branch-qualified production candidate, not yet a production-admitted mode. The next decision point is the paired MultiSWAP-MODFLOW subset experiment. Canonical integration should preserve the opt-in boundary and should not make A28 the default.
