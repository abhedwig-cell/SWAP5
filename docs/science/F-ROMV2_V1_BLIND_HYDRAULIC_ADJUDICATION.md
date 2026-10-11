# F-ROMV2 V1 blind hydraulic adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-V1  
**Frozen decision:** **V2_V1_C2_BLIND_HYDRAULIC_FEASIBILITY_PASS**  
**Adjudication:** **BLIND HYDRAULIC FEASIBILITY PASS, DOMAIN COVERAGE LIMITS CURRENT COMPUTATIONAL VALUE**

## 1. Scope

V1 tests the frozen two-state C2 local conservative closure after canonical admission of the independent F-ROMV2 proposition.

It does not test:

- production ROM readiness;
- cross-material transfer;
- root uptake or evapotranspiration;
- drought stress;
- live MODFLOW coupling;
- ponding/runoff thresholds;
- a formal performance host.

Old H01-H04 histories are not reused as blind evidence.

The V1 execution branch and harness are intentionally non-canonical. Canonical imports only preregistration, immutable provenance, result summary and scientific adjudication.

## 2. Immutable execution

Dedicated workflow run **35441133786**, job **105891994940**, executed head
`2ef240fb390b107bffba263ad779dc2bdda23669`.

Artifact:

- ID: **10583941868**
- digest: `sha256:26928a0dbc9dfc0c422505a86dbf70e47ccee03bef71c54932d11d97d277d276`

The O0 and O2 trajectory payloads are bitwise identical with SHA-256

`68207a1c2d0d381cb0801fc4b74e0946145a8e8a969f4aba9e24e1ee9ef99d7a`.

The accepted trajectory library contains 768 B01 states: 512 regenerated training states and 256 newly generated validation states over V01-V04.

All trajectory authority gates pass. Maximum accepted-step transaction mass residual is about `2.20e-14 cm`.

## 3. Frozen C2 candidate

C2 carries only:

1. total 0-160 cm water storage;
2. the difference between mean water content in the upper and lower 80 cm.

The closure is a forcing-specific one-nearest-neighbour transition table.

There is:

- no regression;
- no neural network;
- no interpolation;
- no fitted distance threshold;
- no hidden mass-correction flux.

A reduced transition is allowed only when the forcing tuple exists in training and the recursive C2 state lies inside the closed forcing-specific training convex hull.

Otherwise the route fails closed to the accepted full-order transition.

The forcing-only comparator uses the **same realized fallback mask**. Therefore the C2 versus forcing-only comparison isolates state-information value rather than rewarding C2 for using Reference more often.

## 4. Integrity result

All non-negotiable integrity gates pass:

- nonfinite published states: 0;
- reconstructed water-content bound failures: 0;
- structural water-ledger failures: 0;
- OOD fail-open events: 0;
- missed V04 forcing-OOD events: 0;
- V04 fail-closed control: PASS.

This is the main difference from historical F-ROMV Stage 1. The new local closure does not exhibit the catastrophic in-domain instability of the global bilinear model.

## 5. Blind hydrological information value

On pooled V01-V03 evidence, under an identical fallback mask:

| metric | C2 | forcing-only |
|---|---:|---:|
| total-storage RMSE | 0.000501 cm | 0.003992 cm |
| cumulative bottom-exchange RMSE | 0.001003 cm | 0.005248 cm |

C2 therefore passes both preregistered state-information-value criteria.

This is a genuine blind result: V01-V04 were generated only after the closure, OOD rule and comparator were frozen.

The result does **not** mean that C2 is already accurate enough for a particular application. No application-specific numerical tolerance was selected from these values.

## 6. History-level interpretation

### V01, repeated multi-regime sequence

C2 publishes 60 of 63 transitions itself. Only 3 transitions fall outside the state-domain gate.

Key results:

- fallback fraction: 4.76%;
- total-storage RMSE: 0.000866 cm;
- cumulative bottom-exchange RMSE: 0.001691 cm;
- final cumulative bottom-exchange error: -0.003253 cm;
- actual cumulative bottom exchange: 0.207575 cm;
- bottom-flux sign errors: 0;
- all four reversal steps are reproduced exactly.

This is the strongest evidence that C2 has useful local hydrological information.

However terminal bottom-flux magnitude remains much less accurate than storage:
RMSE is about 0.219 cm d-1 and maximum absolute error about 0.556 cm d-1.

That distinction is central to purpose-dependent acceptance. V01 can look strong for cumulative balance while remaining questionable for instantaneous flux applications.

### V02, asymmetric-duration/state-memory challenge

Only 11 of 63 transitions remain inside the reduced domain.

Fallback fraction is **82.54%**.

The hybrid therefore has zero hydrological error on this history, but that is mainly a full-order result. It must not be presented as C2 accuracy.

V02 demonstrates a coverage problem, not a fidelity success.

### V03, rapid regime switching

Only 6 of 63 transitions are reduced.

Fallback fraction is **90.48%**.

The published hybrid preserves all seven bottom-flux reversal steps and has small cumulative errors, but almost all of that apparent robustness is purchased through full-order fallback.

This is insufficient evidence for a useful fast-event ROM.

### V04, explicit OOD control

V04 intentionally contains forcing tuples that were absent from training.

The route fails closed exactly as intended:

- forcing-OOD transitions: 39;
- state-OOD transitions: 17;
- total fallback transitions: 56/63;
- one later re-entry into the qualified reduced domain;
- OOD fail-open count: 0.

V04 is a safety success, not an acceleration target.

## 7. Fallback-imposed computational ceiling

Before measuring any clock time, fallback alone imposes an upper bound on possible hybrid speedup.

If:

- every fallback costs exactly one full-order interval;
- reduced transitions cost **zero**;
- OOD checks and orchestration cost **zero**;

then the best possible speedup is `1/fallback_fraction`.

This deliberately optimistic bound gives:

| history | fallback | impossible-to-exceed ideal speedup |
|---|---:|---:|
| V01 | 4.76% | 21.0x |
| V02 | 82.54% | 1.212x |
| V03 | 90.48% | 1.105x |
| V04 | 88.89% | 1.125x |
| pooled V01-V03 | 59.26% | 1.688x |
| pooled V01-V04 | 66.67% | 1.500x |

Real speedup must be lower because reduced lookup, OOD checking, fallback orchestration and non-soil-water work are not free.

This is not a performance benchmark. It is a mathematical ceiling induced by the frozen domain policy.

It changes the computational-value diagnosis: **domain coverage is now the primary obstacle**.

## 8. Purpose-dependent interpretation

### Long-term regional water balance

**Promising but not qualified.**

V01 demonstrates small blind storage and cumulative bottom-exchange errors with high reduced coverage. But V02/V03 show that current C2 coverage collapses under different sequencing, and V1 contains neither ET nor seasonal/multi-year accumulation.

### Operational soil moisture and drought

**Not tested.**

There is no root-water uptake, ET stress, drought persistence/recovery or data-assimilation evidence.

### Groundwater-coupled many-column simulation

**Promising local hydraulic signal, not qualified.**

Flux sign and reversal timing are encouraging, but instantaneous bottom-flux magnitude error is much larger than storage error. Current fallback coverage also threatens system speedup.

### Fast-event / threshold-sensitive simulation

**Not qualified.**

Correct reversal ordering alone is insufficient. V1 does not test ponding, runoff or other process thresholds, and the strongest rapid-switch history is almost entirely full-order fallback.

### Scientific process/extreme-event inference

**Not qualified.**

C2 deliberately discards detailed profile structure and V1 supplies no evidence that this discarded information is irrelevant to process attribution.

## 9. Scientific conclusion

V1 answers one question positively:

> **A two-state, fail-closed, local conservative representation contains blind predictive hydraulic information beyond forcing identity for B01.**

It does not answer the broader value question positively.

The strongest new negative finding is:

> **The current frozen reduced domain is too narrow under asymmetric and rapidly switching histories for broad computational acceleration to be plausible without a different reduction/domain architecture.**

This is not permission to loosen the convex-hull gate after observing V1. That would consume the blind evidence.

## 10. Next research direction

The next discriminator should not be post-hoc C2 OOD tuning.

Two tasks are justified.

First, derive purpose-specific acceptance logic from application needs, observational/model uncertainty and hydrological decision sensitivity before any final application validation.

Second, test an **independently specified quasi-steady or integrated-manifold physical reduction** aimed at regional and groundwater-coupled use. MetaSWAP is precedent for the research question, not an implementation donor.

A physical reduction may accept poorer fast-event fidelity in exchange for much broader state-domain coverage and lower online cost. It should be compared against C2, coarse Richards and current direct routes on the same eventual cost-fidelity frontier.

Formal timing of C2 is not yet the highest-value next experiment. With 82-90% fallback in two of three known-forcing challenge histories, a performance run would mostly measure the full-order route.

Production ROM remains unauthorized.
