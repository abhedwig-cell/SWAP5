# F-RG01C — Fixed-Denominator SWAP5-v1 Completion Model & Reproducible Program Progress Authority

Status: `NORMATIVE_PROGRAM_GOVERNANCE_ADDENDUM`

Model: `SWAP5_V1_COMPLETION_MODEL_V1`

Model version: `1.0.0`

Parent governance authorities:

- F-RG01: `regie/f-rg01-post-rb1-program-rebaseline@09ef05c60c5e45af218980001c8ad8ec30da2e9e`
- F-RG01A: `regie/f-rg01a-parallel-research-isolation-contract-ownership-policy@4553204468695553cf69a48d1c97598c471156d6`
- F-RG01B: `regie/f-rg01b-runtime-resumption-execution-policy@5e2561d9051fba81769565291b1bf3089c7ddcd9`

Current-canonical snapshot used for the final calculation:

`integration/f-ci-canonical@df51575e18777856a47a5d0d1e2e1c7456be4601`

Tree: `9102c9ac3c9bfceea8b7a9e94b2d1ef48c81b363`

Immediate parent: `2a0db2524fba6e258316ce82630c60ea1c9c673a` (`F-CI55R`).

The `df51575e...` delta is repository knowledge/documentation only and earns no new production-capability credit.

## 1. Decision

F-RG01C replaces ad-hoc or expert-estimated SWAP5 program percentages with one fixed-denominator, evidence-bound and reproducible completion model.

The model is intentionally independent of branch count, commit count and workunit count. Those quantities receive zero completion credit.

Progress is measured as:

`PROGRAM -> DOMAIN -> CAPABILITY -> REQUIRED EVIDENCE GATES`

Each v1 capability has a fixed weight. Each capability receives credit only for evidence gates that are demonstrably satisfied by repository authority. New work does not silently enlarge or shrink the denominator.

The denominator defined here is frozen as:

`SWAP5_V1_COMPLETION_MODEL_V1`

Any substantive addition/removal/reweighting of v1 capabilities requires a new explicit model version and a historical restatement. It may not be performed during an ordinary progress recalculation.

This governance work changes no production source, reopens neither RB1 nor previous scientific qualification, and does not alter the SWAP Core Architecture Invariants.

## 2. Three headline measurements

### A. Restricted Production Baseline

The immutable restricted baseline is `SWAP5-RB1-v1`.

Final release authority:

`release/f-rb02-restricted-production-baseline-v1-final-authority@b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0`

The release authority records 15 required capabilities, 15 passing, zero required gaps and a frozen denominator. Its exact-head release workflow is green.

Therefore:

**Restricted Production Baseline = 100.0%**

Post-RB1 work can never lower this number.

### B. Technical SWAP5 Engine

Technical Engine is the normalized subset D01–D14.

Frozen technical denominator weight: **79.0**

Current earned technical weight: **70.425**

Measured technical completion:

`100 * 70.425 / 79 = 89.145569620253%`

A hard production-critical qualification ceiling is currently active at **89.0%**, because required macropore production coverage and bounded-cost/fallback production qualification remain below `INDEPENDENTLY_QUALIFIED`.

Therefore the two technical figures are deliberately distinguished:

- measured completion: **89.1456%**;
- gate-capped technical readiness: **89.0%**.

This demonstrates why a ceiling is necessary: accumulated proportional credit may cross a threshold even while a production-critical capability remains insufficiently qualified.

### C. Overall SWAP5-v1 Program

Overall denominator weight: **100.0 exactly**

Current earned weight: **82.404545454545**

Measured completion:

**82.404545454545%**

The active overall ceiling is 89.0%, so the current raw measurement is not numerically capped.

Thus:

**Overall SWAP5-v1 Program = 82.4045%**

This is a readiness/progress measure, not a claim that the remaining 17.5955 percentage points are equal in scientific difficulty or calendar duration.

## 3. Frozen denominator

The overall denominator is frozen as follows.

| Domain | Scope | Weight | Current earned | Domain completion |
|---|---|---:|---:|---:|
| D01 | Kernel / transactions / generic time / mass | 8.0 | 8.000 | 100.0% |
| D02 | State / persistence / restart | 7.0 | 7.000 | 100.0% |
| D03 | Full Richards / reference solver | 8.0 | 8.000 | 100.0% |
| D04 | Soil-water solver interface | 5.0 | 5.000 | 100.0% |
| D05 | ET / root uptake / surface evaporation | 6.0 | 6.000 | 100.0% |
| D06 | Drainage / restricted surface-water completion | 5.0 | 5.000 | 100.0% |
| D07 | Crop / WOFOST | 5.0 | 5.000 | 100.0% |
| D08 | Soil temperature and snow required profile | 3.0 | 3.000 | 100.0% |
| D09 | Other required production physics | 5.0 | 2.000 | 40.0% |
| D10 | Serialized MultiSWAP | 4.0 | 4.000 | 100.0% |
| D11 | Parallel MultiSWAP | 4.0 | 3.175 | 79.375% |
| D12 | Runtime composition | 4.0 | 4.000 | 100.0% |
| D13 | Groundwater interface and coupling | 10.0 | 7.600 | 76.0% |
| D14 | Performance / bounded-cost / fallback | 5.0 | 2.650 | 53.0% |
| D15 | Permanent testbank | 7.0 | 5.875 | 83.9286% |
| D16 | Scientific traceability / documentation | 6.0 | 3.100 | 51.6667% |
| D17 | Status-A readiness | 5.0 | 0.454545 | 9.0909% |
| D18 | Governance / reproducibility / release evidence | 3.0 | 2.550 | 85.0% |
| **Total** | **SWAP5-v1** | **100.0** | **82.404545** | **82.4045%** |

D01–D14 sum to exactly 79.0 and define the Technical Engine denominator. D15–D18 are program-readiness domains and are excluded from the Technical Engine percentage to prevent documentation/Status-A work from being mistaken for executable-engine completion.

## 4. Maturity and credit rules

The fixed maturity ladder is:

`NOT_STARTED -> RESEARCH_ONLY -> CONTRACT_ESTABLISHED -> IMPLEMENTED -> OWNER_TESTED -> OWNER_QUALIFIED -> INDEPENDENTLY_QUALIFIED -> CANONICAL_ADMITTED -> PRESERVED_REGRESSION_PROTECTED -> RELEASE_READY`

For a normal production capability, fixed gate credit is:

| Gate | Credit |
|---|---:|
| contract/scope | 10% |
| implementation | 25% |
| owner tested | 10% |
| owner qualified | 10% |
| independently qualified | 15% |
| canonical admitted | 20% |
| preservation/regression protected | 10% |
| **Total** | **100%** |

Consequently an implemented-only capability cannot be described as almost complete. A production capability that is independently qualified but not admitted receives at most 70% of its capability weight; canonical admission lifts that to 90%; preservation closes the final 10%.

For non-production evidence capabilities the fixed profile is:

- scope 10%;
- artifact/case implementation 25%;
- owner verification 10%;
- qualified closeout 35%;
- current reconciliation/preservation 20%.

Status-A readiness is the one explicit special ratio: `CLOSED public requirements / 22` at the latest qualified F-DOC15 authority. This is readiness against the governed public baseline, not formal Status-A certification.

No other fractional credit may be invented by expert judgement. A new kind of fractional rule requires a new model version.

## 5. Evidence-bound current interpretation

Important current capability states are:

- WOF43A is independently qualified, canonically admitted and preserved through F-CI51/F-CI51P.
- PM08D7 restricted fixed-weir runtime is independently qualified, admitted and preserved through F-CI52/F-CI52P.
- F-GC18R transactional groundwater exchange is independently qualified, admitted and preserved through F-CI53/F-CI53P.
- F-GC19 mass-ledger capability is canonically admitted through F-CI54.
- exact accepted bottom-interface exchange is independently qualified and closed through F-CI55R.
- F-GC21 restricted generic-window predictor-corrector is owner-qualified at `1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f` and independently qualified by F-VQ64 at `466119889a3f09b33ede638322e897bded2472a3`; it is **not yet canonically admitted**, so capability G04 receives exactly 70% credit.
- complete direct MODFLOW/aquifer end-to-end production coupling is not yet qualified/admitted; G05 receives contract-level credit only.
- scheduled/fixed irrigation has independent scientific qualification evidence but the required complete production path is not yet admitted/preserved; O01 receives 70%.
- required macropore production coverage has only contract/option-level evidence in the audited authority chain; O02 receives 10%.
- bounded-cost/fallback remains an explicit production objective but is not production-qualified; PF02 receives 10%.
- F-TB09 qualifies the catalog itself, but explicitly does not claim integrated-physics result qualification; T02 receives 80% pending current reconciliation.
- F-TB10 is blocked by the nonstationary temporal acceptance-policy/provenance gap; T03 receives 45% and no scientific qualification credit.
- F-DOC16 has a green exact-head conceptual-foundation qualification, but is not yet reconciled into an exact-current program documentation authority; DOC02 receives 80%.
- the latest qualified F-DOC15 remains `NOT_READY`: only public requirements 5.1 and 5.2 are CLOSED. Status-A readiness is therefore exactly `2/22 = 9.090909%`.

## 6. Hard gates and ceilings

Proportional progress is not sufficient for safety- or authority-critical conditions. V1 therefore freezes the following ceilings.

| Hard gate | Condition | Technical ceiling | Overall ceiling | Active now? |
|---|---|---:|---:|---|
| HG01 MASS | proven required-path mass-conservation failure | 49% | 49% | no |
| HG02 TRANSACTION | committed-state pollution / rollback-commit failure | 59% | 59% | no |
| HG03 RESTART | required restart correctness failure | 69% | 69% | no |
| HG04 REFERENCE | Full Richards reference unavailable/unqualified | 39% | 39% | no |
| HG05 OWNERSHIP | unresolved competing production ownership | 79% | 79% | no |
| HG06 PRODUCTION QUALIFICATION | required production-critical capability below independent qualification | 89% | 89% | **yes** |
| HG07 TESTBANK | critical integrated conservation/regression qualification unavailable | — | 92% | **yes** |
| HG08 STATUS-A READINESS | formal readiness below 22/22 CLOSED | — | 95% | **yes** |

No current repository evidence establishes an active mass, transaction, restart or Full-Richards-reference failure, nor unresolved competing production ownership. The active ceilings arise from incompleteness, not a proven correctness regression.

## 7. Remaining work expressed as percentage contribution

The remaining **17.595454545455 overall percentage points** decompose as:

| Domain | Remaining pp | Main content |
|---|---:|---|
| D17 Status-A | 4.5455 | remaining 20/22 public-baseline rows plus controlled WR-QA-2024 reconciliation |
| D09 required production physics | 3.0000 | irrigation admission/preservation and macropore production coverage |
| D16 scientific documentation/evidence | 2.9000 | conceptual reconciliation, parameter/theory/user guidance, validation/sensitivity/uncertainty/fitness evidence |
| D13 groundwater coupling | 2.4000 | F-GC21 admission/preservation and end-to-end direct groundwater/MODFLOW production qualification |
| D14 performance/fallback | 2.3500 | bounded-cost/fallback and production-scale large-batch evidence |
| D15 testbank | 1.1250 | TB09 current reconciliation and TB10-class integrated executable qualification |
| D11 parallel MultiSWAP | 0.8250 | production-scale difficult-column/failure-isolation qualification |
| D18 release evidence | 0.4500 | final exact-current v1 release/readiness evidence pack |

This backlog is the meaning of the remaining percentage. New small workunits do not increase completion unless they close one of these frozen capability gates.

## 8. Impact matrix for prioritization

Closing a capability completely would add at most:

| Capability | Technical Engine increase | Overall increase |
|---|---:|---:|
| O02 macropore production coverage | +2.8481 pp | +2.2500 pp |
| G05 end-to-end direct groundwater coupling | +2.2785 pp | +1.8000 pp |
| PF02 bounded-cost/fallback production qualification | +2.2785 pp | +1.8000 pp |
| M12 large-batch/problem-column isolation | +1.0443 pp | +0.8250 pp |
| O01 irrigation production completion | +0.9494 pp | +0.7500 pp |
| G04 predictor-corrector admission/preservation | +0.7595 pp | +0.6000 pp |
| PF03 production-scale throughput evidence | +0.6962 pp | +0.5500 pp |
| A01 Status-A readiness | — | +4.5455 pp |
| DOC03 controlled theory/parameter/user guidance | — | +1.3500 pp |
| DOC04 validation/sensitivity/uncertainty/fitness | — | +1.3500 pp |
| T03 integrated executable testbank | — | +0.8250 pp |

Percentage impact does **not** override dependency ordering, semantic ownership, scientific priority or the F-RG01A parallel-workstream gate. For example, G04 admission may be strategically preferable to a numerically larger isolated capability if it unlocks the coupling dependency chain.

## 9. RossFast ruling

RossFast remains exactly:

`OPTIONAL_STRETCH_CAPABILITY / RESEARCH_ISOLATED`

Its SWAP5-v1 weight is **0%**.

Current research evidence includes `work/f-ross01-fast-mfp-feasibility@3a78d4f8199ebc15908e6e8108a2e4adb8cb5b15` and the frozen F-SI31 research SoilWaterSolver seam at `4190ede0b17e81abe806430cc9a4c94a21995917`.

RossFast success cannot raise SWAP5-v1 completion. RossFast failure cannot lower it. RossFast cannot block v1 unless a later explicit scope/model-version authority changes that classification.

## 10. Energy-balance scope ruling

For this repository-bound V1 audit, the energy balance is **not a frozen SWAP5-v1 requirement**.

The live repository search found no F-EB branch and no repository code-search result establishing a current energy-balance production authority. Therefore this model cannot convert chat history or external research evidence into production completion credit.

Current model classification:

- research maturity: `UNSCORED_EXTERNAL_OR_UNBOUND_RESEARCH` for this repository calculation;
- architectural readiness: no repository-bound v1 authority established by this audit;
- production implementation: not established as a v1 authority;
- production qualification: not established;
- canonical admission: no;
- SWAP5-v1 requirement: no;
- V1 weight: **0%**.

This does **not** dismiss the scientific value or maturity of ongoing energy-balance research. It means only that inclusion in SWAP5-v1 must first be an explicit governance decision. If v1 inclusion is chosen, create `SWAP5_V1_COMPLETION_MODEL_V2`, record the rationale and report V1-versus-V2 historical percentage effects. Do not silently alter V1.

## 11. Scope uncertainty versus measured completion

Measured completion and scope uncertainty are separate.

The percentages above are exact under model V1 and the named evidence snapshot. They are not confidence intervals.

Current material uncertainties are:

1. controlled `WR-QA-2024` full text has not been obtained; this limits confidence in formal Status-A interpretation but does not change the reproducible `2/22` public-baseline count;
2. energy-balance inclusion is a possible future governance choice but is not a v1 denominator item today;
3. downstream coupling scope may mature further, but new discoveries cannot alter V1 weight without explicit model-version governance.

Do not lower the percentage merely because scientific uncertainty exists. Record the uncertainty and update evidence or model version explicitly.

## 12. Denominator versioning rule

V1 weights are frozen.

If a capability must genuinely be added, removed or reweighted:

1. create a new model version;
2. preserve V1 unchanged;
3. state the scope decision and rationale;
4. show old and new denominators;
5. recalculate the same historical evidence snapshot under both versions;
6. report the percentage discontinuity caused by the scope decision separately from actual engineering progress.

Normal workunit completion changes only maturity/evidence states, never denominator weights.

## 13. Recalculation protocol

Recalculate progress using the unchanged V1 denominator:

- after roughly 5–10 substantive closeouts;
- after a major canonical admission;
- after resolution of a major serial or hard gate;
- before a major release/readiness decision;
- immediately after an explicit frozen-v1 scope/model-version decision.

The next recalculation is specifically warranted after the next substantial canonical coupling admission (for example F-GC21 if admitted) or after a cluster of approximately 5–10 other substantive closeouts, whichever comes first.

A recalculation must re-read repository authorities. Chat summaries are never evidence authority.

## 14. Relationship to F-RG01 dependency and workstream guidance

This model does not rewrite the historical F-RG01 dependency DAG. It adds a reproducible progress layer over it.

The practical queue implied by current evidence is:

1. canonical-admit/preserve F-GC21 only through the normal serial F-CI route now that F-VQ64 is independently qualified;
2. continue the downstream end-to-end coupling chain without claiming direct MODFLOW production completion prematurely;
3. close required macropore and irrigation production gaps;
4. qualify bounded-cost/fallback and production-scale difficult-column behavior while retaining hard mass conservation and reference mode;
5. unblock the TB10-class integrated scientific testbank using an owned temporal-acceptance policy rather than an invented tolerance;
6. reconcile F-DOC16 and close the bounded F-DOC15 scientific/validation/Status-A backlog;
7. build a final exact-current v1 release/readiness evidence pack only after the applicable production and evidence gates are closed.

F-RG01A still determines safe parallelism by semantic-contract ownership. F-RG01B still permits these workunits to span execution chunks with durable checkpoints. Percentage impact never creates permission for unsafe parallel ownership.

## 15. Machine-readable authorities

The frozen model is persisted at:

`integration/f-rg/SWAP5_V1_COMPLETION_MODEL_V1.json`

The exact current evidence calculation is persisted separately as an observation of that fixed model at:

`integration/f-rg/SWAP5_V1_COMPLETION_SNAPSHOT_20260913.json`

This is not a second evidence source. Repository capability, qualification, canonical and release authorities remain the sources of truth. The model defines the denominator and credit rules; the snapshot records the derived calculation against named authorities.

The model-definition file contains the initial establishment observation made before the moving F-VQ64 workstream closed during this same F-RG01C execution. The final current snapshot supersedes that provisional observation only for current maturity/percentage values; the denominator, weights and credit rules are identical and unchanged.

## 16. Exit

F-RG01C is complete when the model, frozen denominator, current snapshot and closeout authority are persisted and the governance-only diff is verified.

Target:

`QUALIFIED_FIXED_DENOMINATOR_SWAP5_V1_COMPLETION_MODEL_ESTABLISHED`
