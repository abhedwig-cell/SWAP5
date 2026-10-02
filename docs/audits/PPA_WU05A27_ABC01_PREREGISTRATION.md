# PPA-WU05-A27-ABC01 preregistration — production A/B/C hydrologic and performance screen

Date: 2026-10-02  
Status: PREREGISTERED_BEFORE_EXECUTION  
A27 source baseline: `8f7efe204ed6a9f8014687b9388f52b217e122a5`  
Reconciled canonical: `800f6a9b429ed2a392e4c3778951bb92eca042aa`

## Question

Measure the current production alternatives as they actually exist. Do not repair RFM first.

The three arms are:

- **A — matrix Reference:** serialized production backend, Reference Richards, no fast-domain optional state.
- **B — standard macropore:** serialized production backend, current standard SWAP macropore optional state and outer corrector runtime, Reference Richards.
- **C — admitted RFM:** serialized production backend, dedicated RFM optional state, A26 accepted-state-frozen first-order split, Reference Richards.

The A27 pressure-aware research seam, cohort/profile prototypes and signed research source are excluded from C.

## Common matrix definition

Use the same ten-cell 0–100 cm matrix grid, bottom mode 7, numerical tolerances and transaction policy in all arms.

Use two repository Staringreeks2018 materials without changing catalog hydraulic parameters:

- B01: theta_r 0.02000000, theta_s 0.42749391, alpha 0.02165898, n 1.73473668, lambda 0.98087016, Ks 31.22501566 cm/day.
- O05: theta_r 0.01000000, theta_s 0.33670050, alpha 0.03030449, n 2.88750186, lambda 0.07360004, Ks 17.41850374 cm/day.

Initial matrix state is hydrostatic from the regime water-table depth. Fast-domain initial storage is zero in B and C.

## Geometry mapping

No exact identity between standard SWAP domains and RFM endpoint/MB classes is assumed.

Two fixed physical descriptions are used.

### G1 — sparse, IC-dominated

- total top macropore area fraction: 0.05;
- terminating IC fraction of top fast area: 0.75;
- deep/MB fraction: 0.25;
- IC termination depth: 60 cm;
- standard characteristic diameter: 4 cm;
- RFM endpoint area fraction: 0.0375;
- RFM endpoint contact thickness: 20 cm;
- RFM exchange length: 20 cm.

Standard B uses two domains with fractions 0.75/0.25 and bottoms at nodes 6/10.  
RFM C uses one terminating endpoint at 60 cm and `f_MB=0.25`; leading MB is the admitted distinct deep receipt.

### G2 — larger, MB-dominated

- total top macropore area fraction: 0.10;
- terminating IC fraction: 0.35;
- deep/MB fraction: 0.65;
- IC termination depth: 40 cm;
- standard characteristic diameter: 8 cm;
- RFM endpoint area fraction: 0.035;
- contact thickness: 20 cm;
- exchange length: 20 cm.

Standard B uses domain fractions 0.35/0.65 and bottoms at nodes 4/10.  
RFM C uses one terminating endpoint at 40 cm and `f_MB=0.65`.

This mapping deliberately leaves the standard deep domain as a standard domain while RFM MB is the admitted fast-through receipt. That difference is a known model-form distinction, not a parameter error.

For B, saturated `cdarcy` is fixed prospectively as

`Ks * top_area_fraction * domain_fraction / exchange_length`.

For B sorptivity, use one soil-level hydraulic anchor, not regime tuning: evaluate the actual default-MvG RFM node sorptivity at h=-100 cm with 64 panels, fix standard alpha=0.5, and choose `SorpMax` so the standard seed law matches that one reference state. The same soil mapping is then used in every regime and both geometries.

RFM structural values not represented by B are fixed before execution:
- sigma_B = 0.65;
- connectivity p = 1.0;
- Z_AH = 20 cm;
- Z_IC = IC termination depth;
- chi_wall = 1;
- 64 sorptivity panels.

No parameter may be changed after case results are seen.

## External forcing ownership

Rainfall is the only surface source. Evaporation, irrigation, runon and snow are zero.

A receives the full rainfall as matrix top flux.

B uses the A9 ownership rule:
- matrix top flux = rainfall × (1 - total top macropore area fraction);
- standard macropore top forcing receives the full rainfall source and internally requests only its top-area share.

Thus requested matrix plus fast-domain surface receipt equals the same rainfall amount without double counting.

C receives the full rainfall through the admitted RFM surface forcing and owns its A15/A16 split internally.

## Eight regimes

Each case uses a 0.20 day window and base outer interval 0.01 day.

| ID | Name | Water table cm | Rain forcing |
| --- | --- | ---: | --- |
| R1 | dry short intense | -300 | 8 cm/day for t < 0.04 d |
| R2 | moderate short intense | -150 | 8 cm/day for t < 0.04 d |
| R3 | wet/near-saturated storm | -20 | 4 cm/day for t < 0.04 d |
| R4 | long moderate | -150 | 1 cm/day for full 0.20 d |
| R5 | repeated storms | -150 | 5 cm/day for 0–0.03 and 0.10–0.13 d |
| R6 | low-flow control | -150 | 0.10 cm/day for full 0.20 d |
| R7 | terminating-IC loading | -200 | 3 cm/day for 0–0.08 d |
| R8 | deep-route stress | -100 | 6 cm/day for 0–0.08 d |

Run all 2 soils × 2 geometries × 8 regimes for A/B/C. A is intentionally repeated across geometry IDs so every comparison record has an identical three-arm key.

A production route that rejects a case because it leaves its admitted envelope is recorded as `NOT_ADMITTED`; do not coerce it to run.

## Production numerical policy

All arms use the same canonical full/half transaction mode and Reference matrix tolerances.

B uses the current non-perched outer-corrector standard macropore route:
- inner-Richards exchange disabled;
- source-reduction retry disabled;
- max 40 correctors;
- relative exchange tolerance 1e-8;
- damping previous weight 0.5;
- solver/internal mass tolerances 1e-8 cm;
- rapid drainage disabled.

PERCH21 is not activated in ABC01. A separate perched benchmark would require a matched RFM physical question.

## Recorded observables

For every arm/case persist:
- completion/admission status;
- wall time;
- cumulative canonical mass in/out and maximum mass residual;
- cumulative bottom outward exchange;
- external fast-domain outflow inferred as total external out minus positive bottom outward exchange, valid here because other external sinks are disabled;
- final matrix, fast-domain, ponding and total storage;
- final pressure head and theta at nodes 1, 5 and 10;
- transaction calls, attempts, retries, nonlinear iterations, backtracking and HeadCalc calls;
- minimum accepted substep.

This first screen does not pretend to recover an internal B or C wall-exchange trajectory from the final state.

## Equivalence classification

Automated classification may assign only:

- **E0** when B/C final storage, total drainage, representative theta and fast storage are numerically indistinguishable within 1e-8 cm or theta units.
- **E1** when both complete, both mass residuals <=1e-6 cm, final total-storage and total-drainage differences are each <= max(0.05 cm, 5% of accepted surface input), and maximum representative theta difference <=0.02.
- **REVIEW_MODEL_FORM** otherwise when both complete.
- **C_NOT_ADMITTED** or **B_NOT_ADMITTED** when that production arm does not complete.

E2 requires a documented attribution to a preregistered model-form difference. E3 requires an unexplained qualitative divergence after review. The analyzer must not auto-promote REVIEW_MODEL_FORM to E2 or E3.

## Performance protocol

The broad screen records one wall time per arm/case for attribution only.

For four representative keys (R2/G1/B01, R4/G2/B01, R5/G1/O05, R6/G2/O05), run one unrecorded warm-up followed by five fresh-state repetitions of each arm. Report median and range. A speed ratio is reported only when both compared arms complete all repetitions.

CI-run timing is machine-specific evidence. It is not a portable speed guarantee.

## Stop/continuation rules

- Mass/ownership failure is a hard benchmark failure.
- Production fail-closed is retained as an envelope result.
- A faster C with REVIEW_MODEL_FORM is not a useful acceleration claim until the hydrologic difference is classified.
- Do not use A27 pressure-aware research code to improve C during ABC01.
- Do not tune B or C after observing the results.
