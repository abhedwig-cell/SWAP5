# F-PE-TIMEARCH12 result — H0-gated automatic controller application

Date: 2026-09-28

Final status:

`CLOSED_H0_APPLICATION_NO_GAIN`

Canonical base:

`integration/f-ci-canonical@eb3a5718a5b7b0b24ebe744e595b781882e7f25a`

Qualification authority:

- Actions run: `36430340410`;
- job: `108954595597`;
- conclusion: SUCCESS.

## Frozen candidate

Normal intervals at or below 0.02 d retained legacy Reference ownership.

A normalized accepted-history proposal could request an outer interval up to 0.08 d.

For requested large intervals:

- H0 SAFE -> one full large solve;
- H0 blocked/unavailable -> direct two-half conservative route;
- failed released full solve -> two-half fallback.

H0 remained exactly the PREDICT03 validated rule:

- two accepted history intervals available;
- origin-frozen corrected dynamic-top predictor available;
- origin-frozen runoff potential false;
- most recent normalized accepted head movement r_last <= 0.10.

No material or regime identifier was used.

## Validation bank

16 new cases:

- four hydraulic archetypes;
- DRY5, TRANS5, WET5 and POND5;
- no reuse of PREDICT03 validation states.

## Result

H0 controller activity:

- released large intervals: 9;
- blocked large intervals: 11;
- released-full fallback failures: 0.

Physical result:

- strict Reference passes: 5/16;
- strict wet/ponding preservation: FAIL;
- P-C1 passes: 16/16;
- P-C1 wet/ponding preservation: PASS.

Performance:

- median deterministic work reduction: 6.7%;
- required: 15%;
- non-inferior cases: 87.5%;
- no regime median work regression.

Median work reduction by regime:

- DRY: 31.25%;
- TRANSITION: 10.61%;
- WET: 6.67%;
- POND: 0%.

## Interpretation

The validated H0 classifier successfully prevents the large wet/ponding failures seen in earlier state-aware controllers at the practical P-C1 level.

However, it is intentionally conservative. About half of candidate large intervals are blocked, and the remaining full-step releases do not create enough aggregate work reduction on the equally weighted validation bank.

The result is therefore not an AUTO_REFERENCE candidate:

- strict trajectory equivalence is insufficient;
- median work gain is below the frozen advancement threshold.

It is also not a qualified practical/coupling algorithm candidate because the performance gate fails despite 16/16 P-C1 accuracy.

## Decision

No H0 controller admission.

Do not relax the 15% performance threshold post hoc.

Do not retune the frozen H0 r_last threshold in this workunit.

## What remains supported

The architecture redesign itself remains strongly supported.

The sequence now shows:

- the old global DTMAX is materially active;
- safe large-step headroom exists;
- dynamic wet transitions require more than iteration-count heuristics;
- a cheap history classifier can recover robustness;
- but the current classifier is too conservative for broad end-to-end gain.

A successor must add genuinely new information or a different objective, not another threshold tweak.

Valid future directions:

1. representatively workload-weighted throughput qualification on real BOFEK/LHM distributions;
2. richer but still cheap multi-step predictor features;
3. a boundary-transition-aware predictor using within-step/tangent information;
4. end-to-end coupling objectives where local column trajectory equivalence is not the sole criterion.

