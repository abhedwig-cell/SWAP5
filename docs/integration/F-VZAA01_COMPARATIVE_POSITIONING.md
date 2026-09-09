# F-VZAA01 - Comparative positioning against LayeredMFP, RossFast and Finite Water Content

## Purpose

This note prevents F-VZAA01 from creating an unnecessary fourth production soil-water solver family merely because VZAA is scientifically interesting.

The comparison is based on the live SWAP5 workstream evidence observed on 2026-09-09:

- VZAA: `work/f-vzaa01-vadose-zone-analytical-assessment`, after conservation/boundary/runtime reconstruction at commit `eeb3bb1b762f93ff566ece5fd00c01694ea88dfc`;
- LayeredMFP: `work/f-lmfp09-hydraulic-envelope-geometry`, observed head `7d164e19cc70a831436cdb0a15514672f58179fd`;
- RossFast: `work/f-ross01-fast-mfp-feasibility`, observed head `a351de29183cb896f205e318af6522bc02bb95b3`;
- Finite Water Content: `work/f-fwc01-finite-water-content-assessment`, observed head `eebd347a486bf7597de9b5d5809ad91b19342084`.

No production admission is inferred from any experimental qualification below.

## 1. Comparison by SWAP5 hard requirement

| Requirement | Published VZAA | LayeredMFP current evidence | RossFast current evidence | FWC current evidence |
|---|---|---|---|---|
| Exact accepted-step mass conservation | **Fails as complete published method**. Narrow fixed-layer Eq. (8) identity is algebraically conservative, but published complete runs retain residuals. | **Established to roundoff in tested transient experimental scope** in F-LMFP08. | Open for SWAP5 accepted-step ledger. | Published method is conservation-oriented/finite-volume, but SWAP5 accepted-step qualification remains open. |
| Prescribed bottom flux/head | **Fails published formulation**. Lower boundary is output-driven. | Not yet qualified for groundwater/MODFLOW. | Open. | Moving-water-table lineage exists; generic SWAP/MODFLOW head/flux contract remains open. |
| Heterogeneous layers/interfaces | Published embedded-clay case degrades; derivation was uniform-soil based. | Interface physics has been isolated and is an active qualification subject; broad heterogeneous admission not yet granted. | Open. | Published lineage includes layered soils, but SWAP qualification remains open. |
| Bidirectional/capillary behaviour | Upward groundwater contribution is explicitly present in the published flux construction, but not as a prescribed interface contract. | Groundwater/capillary coupling not yet admitted in current hydraulic scope. | Physically promising through Richards/MFP formulation, SWAP groundwater contract open. | Moving/rising/falling water-table lineage exists; exact SWAP interface remains open. |
| Compact persistent column state | **Fails literal full-history formulation** because half-order history grows with `N_steps`. | Current qualified representation adds no new column state; lookup data are immutable/shared. | No inherent full temporal-history state identified in current theory status; full SWAP state qualification remains open. | Dynamic front/event state can grow and remains a bounded-state blocker. |
| Predictable runtime | Sequential sweep is attractive, but literal history work grows with run length and adaptive substeps add variability. | F-LMFP08 establishes bounded O(1) homogeneous-face lookup; total template/cardinality and broader solver cost still under qualification. | Non-iterative MFP route is promising and independent studies report speedups, but bounded local work for SWAP remains open. | Explicit/non-iterative, but dynamic front/event count and branch cost are not yet bounded. |
| Response tangent for coupling | Not provided. | Not admitted yet. | Open. | Open. |
| Generic SWAP hydraulic catalogue | Paper claims general h-theta-K-D substitution, but this has not been qualified and layered performance is weak. | Actively qualifying a generic MFP coordinate/envelope and shared constitutive representation. | Generalization beyond Brooks-Corey is supported externally, full SWAP catalogue open. | Generic SWAP pressure-head/hydraulic-service fidelity open. |
| Transactional retry/rollback | Possible only if raw/compressed fractional history is itself transactional. | Current experimental architecture preserves rejected-step non-mutation. | Open but no history-state obstacle of VZAA type identified. | Event/front state would require transactional ownership; open. |

## 2. What VZAA adds that is not already the strongest part of LayeredMFP

The VZAA mechanism with the clearest distinct research value is not its mass update or its lower-boundary treatment. Those are weaker than what SWAP5 already requires and, in LayeredMFP's tested scope, weaker than what has already been demonstrated.

The potentially distinct donor is the **history-aware analytical estimate of transient diffusive moisture flux**, combined with an explicit split between a surface-driven transient contribution and a groundwater-driven upward contribution.

That mechanism could be useful in SWAP5 in a narrower role:

1. as a predictor for a conservative solver;
2. as a predictor for bottom/capillary response before a conservative correction;
3. as a diagnostic feature indicating when a cheaper quasi-steady or coarse representation is likely to fail;
4. as an offline donor for fitting a bounded local correction surface;
5. as a reference against which a compact recursive history approximation can be tested.

In these roles, a raw VZAA prediction is not itself an accepted water transfer. Therefore its published mass residual does not contaminate the committed SWAP5 ledger, provided the accepting solver/corrector remains exactly conservative.

## 3. What should not be imported from VZAA without new evidence

The following features should not be copied merely because they are part of the paper:

- the empirical flow-direction coefficient (`c=0.5` downward wetting, `c=2` upward drying) as a universal physical law;
- the empirical water-table storage update using calibrated `phi` and `Sy_min` as the canonical SWAP groundwater storage relation;
- the output-driven lower boundary;
- raw complete moisture history as permanent per-column state;
- unbounded adaptive subdivision;
- a direct assumption that the uniform-soil analytical relation remains valid across sharp material interfaces;
- post hoc mass correction that is accepted without bounding the resulting physical state distortion.

## 4. Standalone conservative VZAA derivative versus LayeredMFP

The conservative projection sketched in the F-VZAA01 conservation reconstruction is mathematically plausible, but it creates a new solver only if the VZAA predictor yields a demonstrated benefit that cannot be obtained more simply inside the existing LayeredMFP framework.

At present, that burden of proof is not met.

LayeredMFP already has, in its qualified experimental F-LMFP08 scope:

- exact transient mass conservation to roundoff;
- exact equal-head and hydrostatic face identities;
- continuous physics-informed Darcian correction;
- fail-closed lookup coverage;
- immutable shared representation data;
- bounded O(1) interpolation per homogeneous face;
- no added persistent column state;
- an unchanged FullRichards reference mode.

F-LMFP09 is extending the hydraulic envelope and representation geometry, including heterogeneous-interface qualification. The workstream therefore already owns the architectural territory that a mass-conserving VZAA derivative would need to rebuild.

### Governance consequence

A separate production-bound `VZAA-derived solver` should **not** be started merely to test the conservation projection.

The default research route should instead be:

- extract any genuinely distinct VZAA transient/capillary predictor;
- test it as a donor mechanism inside an isolated LayeredMFP-compatible harness or common soil-water experimental interface;
- preserve exact LayeredMFP/common-ledger acceptance semantics;
- compare physical error and cost against both current LayeredMFP and FullRichards;
- create a separate solver family only if the evidence demonstrates a materially different applicability envelope or a substantial cost/accuracy advantage that cannot be expressed as a LayeredMFP correction/predictor.

## 5. VZAA versus RossFast

RossFast and VZAA both avoid a global Newton iteration in their core conceptual routes, but their numerical liabilities differ.

RossFast's MFP/Kirchhoff lineage is attractive for SWAP5 because it does not inherently require retaining the entire temporal moisture history. Its unresolved questions are primarily hydraulic generalization, exact SWAP ledger semantics, heterogeneous interfaces, and coupling contracts.

VZAA provides a more explicit time-history-based transient flux estimate, but that same feature is a MultiSWAP liability unless compressed.

Therefore VZAA should not compete with RossFast on the generic claim `non-iterative = faster`. Its only meaningful competitive claim would have to be improved transient/capillary fidelity for a qualified regime at bounded memory and bounded work. That claim has not been demonstrated.

## 6. VZAA versus Finite Water Content

FWC currently has a stronger published conservation lineage than VZAA and published moving-water-table/layered-soil applications. Its main SWAP5 concern is different: dynamic front/event state and branch cost may be difficult to bound, and an important approximate formulation omits a diffusion-like term exposed by later SMVE theory.

This creates a potentially useful cross-track question:

**Can the VZAA transient diffusion-history mechanism help characterize or approximate the diffusion contribution that FWC-style reduced representations omit, without importing VZAA's full-history state or non-conservative complete update?**

That is a donor/research question, not evidence that a hybrid should be built. Any hybrid would need to outperform simpler LayeredMFP or RossFast routes before it deserves architectural complexity.

## 7. Provisional ranking by architectural fit, not scientific merit

Within evidence available now:

1. **LayeredMFP is the most advanced SWAP5-specific reduced-order track.** It already has tested and qualified pieces for exact mass, bounded face evaluation and shared immutable representation, although production, heterogeneous, groundwater and coupling admission remain open.
2. **RossFast remains a strong independent numerical candidate** because its MFP formulation has external literature support and no inherent long-history state, but its SWAP5 hard gates are much less developed.
3. **FWC remains scientifically relevant**, especially for explicit conservation and moving groundwater, but bounded dynamic state/cost and generic SWAP hydraulic service remain serious open questions.
4. **Published VZAA is not competitive as a direct production solver** under SWAP5 invariants because it simultaneously carries mass/bottom-boundary problems and a long-history cost/state burden.

This is not a final solver selection. It is a governance statement about where additional F-VZAA effort is justified.

## 8. Recommended F-VZAA01 direction

F-VZAA01 should now prioritize **donor extraction and falsification**, not standalone solver construction.

Highest-value next tests are:

1. obtain and reproduce the official MATLAB supplement to determine exactly where the reported complete-method mass residual enters and how Eq. (9) is solved;
2. isolate the VZAA transient diffusive/history term from the rest of the published update;
3. test whether that term materially improves a LayeredMFP-style predictor/correction against FullRichards in cases dominated by rapid redistribution, evaporation-driven reversal or capillary rise;
4. replace raw full history only in a separate experiment with a bounded compressed-history approximation and measure error versus literal VZAA history;
5. reject the donor if its incremental accuracy is small relative to its state, preparation and runtime cost;
6. keep groundwater-interface and response-tangent work in the common solver/coupling architecture rather than embedding VZAA-specific MODFLOW logic.

## Provisional positioning decision

`PUBLISHED_VZAA_DIRECT_SOLVER_BLOCKED__STANDALONE_CONSERVATIVE_DERIVATIVE_DEPRIORITIZED_PENDING_DISTINCT_BENEFIT__DONOR_EXTRACTION_PRIORITIZED`

This is deliberately provisional. Gate B reproduction is still open, and no donor experiment has yet been run.