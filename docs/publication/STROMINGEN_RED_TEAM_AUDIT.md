# Stromingen manuscript red-team audit

Date: 2026-09-19
Branch: docs/pub-stromingen-firewall-outline

## Purpose

This audit tests the current Stromingen draft against existing and prospective international paper ownership. The standard is deliberately stricter than simple duplicate-publication avoidance: the overview article should not prefigure the core framing, method, result structure or central figure of an international manuscript.

Risk classes:
- GREEN: descriptive context; safe with source verification.
- AMBER: scientifically meaningful framing that can remain only after de-specificating it.
- RED: overlaps a protected paper claim, method or result and should be removed or rewritten.

## Section-by-section findings

### Section 1: Hydrologische modellering in beweging

Overall: GREEN.

Safe because it describes public instrumentarium context and component roles. The sentence that qualification of component exchange matters is acceptable as generic motivation, but must not be followed by COUPLE-specific semantics or evidence.

### Section 2: SWAP in een veranderende modelomgeving

Overall: GREEN / AMBER.

Safe: long SWAP history, changing software context, need for coupling and reproducibility.

AMBER: phrasing that the hydrological meaning must remain recognizable and controllable through restructuring is close to P1. Keep only as a general modernization requirement; do not add preservation methodology, state-equivalence data, fault injection or migration gates.

### Section 3: Wat SWAP5 op hoofdlijnen verandert

Overall: AMBER.

Risk: references to unambiguous hydrological state, explicit interfaces and controlled execution can start to reveal P1 state-ownership and transactional architecture.

Action: retain only the high-level separation among scientific model core, data handling, execution and coupling. Remove language that sounds like a scientific claim about authoritative state or transaction semantics.

Risk: the paragraph on documentation, reference runs, tests, water balances and reproducibility can become a miniature P1/TRACE method.

Action: keep these only as examples of quality control; do not present them as a novel evidentiary framework.

### Section 4: Van zelfstandig model naar gekoppelde component

Overall: AMBER.

Safe: generic bidirectional interaction between unsaturated zone and groundwater.

RED if expanded: coupling-plane semantics, q_bot/q_u/u, conservative whole-window exchange, retry/rollback, response functions, tangent information, convergence envelopes or E1-E7 evidence.

Risk: explicit wording about multiple land-surface units feeding one groundwater representation points directly toward SCALE/N:1 research framing.

Action: remove the N:1-like example and keep only the generic statement that component discretizations may differ.

### Section 5: MODFLOW 6, Ribasim en de onverzadigde zone

Overall: GREEN / AMBER.

Safe: publicly documented roles and releases.

AMBER: any statement that SWAP5 is the definitive production successor or the adopted NHI unsaturated-zone module. Current public nomenclature uses MultiSWAP as successor to MetaSWAP, while SWAP5 is the modernized SWAP model basis in this project.

Action: maintain explicit nomenclature caution until formal authority is available.

### Section 6: Verschillende schalen, één watersysteem

Overall: AMBER.

Safe only as problem statement.

RED if expanded: equivalent-column validity, transferability, heterogeneity thresholds, prediction of aggregation error, response surfaces or scale-regime maps. These belong to PUB-SG / SCALE.

Action: phrase scale mismatch as an open modelling consideration. Avoid language about which information is retained under aggregation if it becomes a testable criterion.

### Section 7: Implementeren is niet hetzelfde als kwalificeren

Overall: RED / AMBER in current form.

Problem: the current draft compares documentation, historical behaviour, implementation, tests and balances and then discusses how conflicts among those evidence sources should be interpreted. That is too close to TRACE and overlaps P1 qualification framing.

Action: simplify heavily. It is sufficient to say that technical implementation and scientific qualification are different, and that qualification uses multiple established checks appropriate to the capability. Remove the discussion of conflicts among theory/documentation/implementation/history and do not imply a new reconciliation methodology.

### Section 8: Rekentijd en detailniveau

Overall: RED / AMBER in current form.

Problem: the statement that a faster route is usable only for certain states, processes and applications if it agrees sufficiently with a reference is essentially the P2 solver-admissibility research question.

Action: replace with a generic statement that performance alternatives require validation for their intended application. Do not introduce admissibility domains, reference discrepancy or regime-specific validity.

### Section 9: Wat verandert er voor gebruikers en modelbouwers?

Overall: GREEN / AMBER.

Safe: provenance, modular testing, maintainability, explicit component boundaries, workflow governance.

AMBER: statements suggesting that modularity inherently makes fault localization better should be presented as a practical design benefit, not as an evaluated result.

### Section 10: Waar staat de ontwikkeling nu?

Overall: GREEN if rebuilt from current authority before submission.

Critical condition: do not infer readiness from code presence, branch names or planned capability. Every production-status sentence must come from then-current canonical qualification or public programme authority.

### Section 11: Vooruitblik

Overall: RED / AMBER in current form.

Problem: the current list nearly restates the research questions of COUPLE, SCALE, P2, HYDRO-MEMORY and NUM-UNC. Even without answers, it publicly establishes a recognizable research programme before the international manuscripts.

Action: replace exact questions with broad categories: coupling, scale, numerical robustness, drought response and computational feasibility. Do not phrase the international papers' central questions in near-final form.

## Cross-paper ownership audit

| Protected line | Current draft risk | Required treatment |
| --- | --- | --- |
| P1 Model Evolution | Section 3 and 7 | High-level modernization only; no preservation method or transaction science |
| P2 Solver Admissibility | Section 8 and outlook | Performance as practical concern only; no validity domains or reference-discrepancy framing |
| PUB-GC COUPLE | Section 4 and 5 | Generic component coupling only; no coupling semantics/results |
| PUB-SG SCALE | Section 4, 6 and outlook | State scale mismatch only; no equivalent-column or aggregation-validity science |
| PUB-RC ACCELERATE | Section 4 and 8 | Do not discuss information-value or acceleration evidence |
| F-ROM | Section 8 | Omit compact-state / predictive-ambiguity direction |
| HYDRO-MEMORY | Outlook | Mention drought research only as broad application area |
| DIFFICULTY | Section 8 / outlook | No physical predictors or difficulty regimes |
| NUM-UNC | Outlook | No claim about scientific conclusions changing with admissible numerics |
| TRACE | Section 7 | No reconciliation framework, discrepancy taxonomy or evidence-source conflict analysis |

## Red-team conclusion

The article remains viable, but it should be less methodologically self-conscious than the previous draft. Its scientific value for Stromingen should come from synthesis of the Dutch instrumentarium transition, not from previewing the SWAP5 research programme.

The strongest safe article is therefore an overview of: why the instrumentarium is changing; where SWAP5 fits; how the main hydrological components relate conceptually; why qualification matters in general; what is publicly established now; and what broad development directions remain.

Do not compensate for removal of protected detail by adding new quantitative examples. The overview does not need unpublished results to be substantive.