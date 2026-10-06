# Stromingen overview article: publication firewall and article authority

## Status

Working publication authority for the planned Dutch overview article in Stromingen.

This document is deliberately conservative. Its purpose is to support a useful Dutch overview of the evolving hydrological modelling instrumentarium without pre-empting scientific novelty owned by present or prospective international manuscripts.

The article is not intended to become a Dutch-language prepublication of one of the international papers. It should explain context, purpose, scope, component roles, current development status and practical relevance, while keeping new scientific inference, regime boundaries, method novelty and publication-grade evidence with the paper that owns them.

## Governing principle

Stromingen may explain what the instrumentarium is, why it is being developed, how the major hydrological components relate conceptually, and what is already publicly and operationally established.

It should not establish a new scientific method, a new mechanistic inference, a quantified regime boundary, a new qualification theory, a new coupling result, a new solver result, a new scaling result, or a new hydrological finding that is owned or plausibly ownable by an international paper.

Guard question for every paragraph, figure and table:

> Would this paragraph remain valid if every still-open research line below eventually produced a negative result?

If not, it probably contains a research result rather than overview context.

## Publication-authority hierarchy

Use this order for firewall decisions:

1. docs/publication/PUBLICATION_PROGRAMME.md and paper-specific research-design / claim-evidence documents.
2. Explicit preregistrations and admitted publication evidence in docs/publication and docs/publications.
3. Active research propositions such as docs/science/F-ROM_RESEARCH_PROPOSITION.md.
4. Research lines already opened in the SWAP5 documentation/publication project but not yet fully incorporated into PUBLICATION_PROGRAMME.md.
5. This Stromingen plan.

This document does not reassign scientific ownership from an existing paper.

## Protected publication portfolio

### P1: Model evolution / preservation

Protected: evidence-preserving modernization, authoritative state ownership, transactional interval semantics, trial/accepted/committed distinctions where used as scientific method, retry/rollback/commit semantics, qualification-gated migration, and evidence that established scientific behaviour is preserved through architectural change.

Safe in Stromingen: SWAP is being modernized; scientific model content is separated more clearly from I/O, execution and coupling infrastructure; reproducibility, restartability, testing and qualification are design requirements; modernization is staged.

Do not disclose as article novelty: the specific P1 method, publication-grade preservation evidence, fault-injection results, proof that particular transaction semantics preserve model behaviour, or a generalized migration methodology.

### P2: Solver admissibility / replacement

Protected: Reference Richards versus alternative-solver discrepancy, hydrological and numerical admissibility domains, exclusion domains and fail-closed criteria, regime-dependent solver behaviour, accuracy/conservation/cost trade-offs, and predictive solver-selection or exclusion principles.

Safe in Stromingen: computational efficiency matters for regional applications; alternative numerical routes require separate scientific qualification.

Do not disclose: RossFast versus Reference result tables, speedups, admissibility maps, transition regimes, solver-selection rules, physical predictors of solver difficulty, or solver-specific failure mechanisms supporting P2.

### PUB-GC: COUPLE

Protected: scientific correctness of SWAP5-MODFLOW 6 coupling, coupling-plane and hydraulic-head semantics, q_bot/q_u/response-storage interpretation, conservative whole-window exchange, coupling state semantics, retry/rollback/publication, convergence evidence and the publication-grade interface contract.

Safe in Stromingen: SWAP5 is being developed for controlled exchange with groundwater components; MODFLOW 6 is a relevant groundwater component; coupled simulations require explicit exchange of states and fluxes; coupling must be hydrologically and numerically qualified.

Do not disclose: q_bot/q_u/u scientific interpretation as a new result, response curves, response identity, tangent or derivative evidence, E1-E7 results, predictor envelopes, feedback-strength results, coupling-window conclusions or publication-grade conservative-exchange proof.

### PUB-SG: SCALE

Protected: physical validity and failure of spatial aggregation, transferability of equivalent unsaturated-zone columns, effects of heterogeneous forcing/soils/groundwater dynamics, prediction of aggregation error and scale-dependent failure mechanisms.

Safe in Stromingen: coupled components may operate at different spatial scales; scale mismatch is a scientific issue, not only a software issue; N:1 mappings may be technically possible.

Do not disclose: when an equivalent column is valid, quantified aggregation error, thresholds for heterogeneity, predictors of transferability, scale-regime maps or positive/negative SCALE findings.

### PUB-RC: ACCELERATE

Current repository disposition: independent line not admitted; current E4/E5 evidence belongs to PUB-GC unless qualitatively new evidence reopens PUB-RC.

Safe in Stromingen: efficient coupling is a practical design concern.

Do not disclose: supplied finite-window response versus learned black-box history results, oracle/secant/Aitken comparison, E4/E5 information-value findings or convergence-domain results.

Negative or non-continuation results are still publication-owned evidence and do not become free overview material automatically.

### F-ROM: reduced-order soil-water research

Protected: future-relevant compact state representation, predictive equivalence and ambiguity, state compression versus output distinctions, counterexample-driven state enrichment, minimum state conditional on capability/domain, comparison with coarse Richards and RossFast, reduced closure and long-horizon drift, and fail-closed reduced-domain behaviour.

Safe in Stromingen: computational tractability and representation are continuing research topics.

Preferred treatment: omit ROM from the first overview article.

Do not disclose: compact-state hypotheses, predictive-ambiguity experiments, state-dimension findings, ROM gates or experimental results.

### HYDRO-MEMORY

Protected prospective result space: groundwater as buffer/memory/amplifier, drought persistence and recovery, interactions among soil hydraulic properties, groundwater depth, forcing and vegetation response, and transferable hydrological-memory regimes.

Safe in Stromingen: coupled groundwater-root-zone dynamics are scientifically important; the instrumentarium can support research on drought and recovery.

Do not disclose regime classifications, thresholds, response surfaces, groundwater-memory mechanisms as new findings, or preliminary results.

### DIFFICULTY

Protected prospective result space: physical origin of nonlinear numerical difficulty, pre-solve prediction from hydrological state and forcing, and transfer of difficulty regimes across soils, forcing and solvers.

Safe in Stromingen: robust numerical solution remains important for process-based simulation.

Do not disclose predictors, difficulty regimes, transfer findings, or a new claim that physical state predicts numerical difficulty.

### NUM-UNC

Protected prospective result space: scientifically consequential variation caused by allowable numerical choices, path dependence, timestep or solver sensitivity that changes scientific interpretation, and separation of physical and numerical uncertainty.

Safe in Stromingen: numerical choices must be qualified.

Do not disclose magnitude or structure of numerical uncertainty, cases where scientific conclusions change, or threshold/sensitivity results.

### TRACE

Protected prospective result space: discrepancy classes among theory, documentation, implementation and executable evidence; which discrepancies conventional regression testing misses; scientific consequences; and cross-model empirical reconciliation findings.

Safe in Stromingen: model modernization uses theory, documentation, reference behaviour and tests; disagreements between these sources must be investigated before acceptance.

Do not disclose a formal discrepancy taxonomy, frequencies, specific scientifically consequential discrepancies, evidence that particular test classes miss particular discrepancy classes, or cross-model TRACE results.

### Other prospective lines

Treat as protected until ownership is explicitly resolved: adaptive-execution work if it develops a distinct scientific claim; reproducibility or benchmark studies if they become independent manuscripts; MultiSWAP performance and batchability; MultiSWAP qualification; any international SWAP5 model/software overview paper; and later ROM-derived or solver-derived papers.

Default rule: when a claim could plausibly become the central result of a future paper, Stromingen should mention the question rather than answer it.

## Safe article thesis

> The Dutch hydrological modelling landscape is moving toward a more modular instrumentarium in which process-based unsaturated-zone modelling, groundwater flow and surface-water / allocation modelling can be coupled more explicitly. SWAP5 is the modernization path for the SWAP modelling basis within that broader development. The challenge is not merely technical coupling, but maintaining transparent, reproducible and scientifically qualified component behaviour as the instrumentarium evolves.

This thesis is descriptive and does not depend on positive outcomes from COUPLE, SCALE, P2, ROM, HYDRO-MEMORY, DIFFICULTY, NUM-UNC or TRACE.

## Revised article structure

### 1. Hydrological modelling in transition
Set the Dutch hydrological context. Explain why integrated and modular modelling matters. Use public roles of SWAP, MODFLOW 6, Ribasim, iMOD and NHI-like applications. Do not claim an unadopted configuration is the new NHI.

### 2. SWAP in a changing model environment
Connect to the fifty-year SWAP history. Explain long scientific lineage, process-based unsaturated-zone modelling and changed requirements for coupling/reproducibility. Do not expose legacy discrepancies or TRACE cases.

### 3. What SWAP5 is, at overview level
Explain clearer separation among scientific model core, state, I/O, execution and coupling; staged migration; testing and qualification; component use. Avoid transaction-lifecycle novelty, rollback/retry design, state-ownership proof and P1 evidence.

### 4. From standalone calculation to coupled component
Explain conceptually that components exchange states and fluxes during simulation. Avoid q_bot/q_u/u details, whole-window proof, response functions, tangent information, E1-E7 and convergence analysis.

### 5. MODFLOW 6 and Ribasim in the wider instrumentarium
Place SWAP5 in the Dutch modelling ecosystem. Distinguish existing public infrastructure from future SWAP5-specific qualification. Do not claim formal adoption where authority is absent.

### 6. Different scales, one water system
State that components can have different spatial and temporal discretizations and that technical coupling does not by itself demonstrate physical representativeness. Avoid equivalent-column theory, transferability criteria, aggregation errors, thresholds and SCALE predictors.

### 7. Qualification without publishing the qualification science
State generically that theory, documentation, reference cases, water balances and automated tests support staged acceptance. Avoid formal TRACE methodology, P1 method, discrepancy taxonomy, publication evidence tables and fault-injection results.

### 8. Computational feasibility at regional scale
Acknowledge performance as a design consideration. Avoid speedups, solver ranking, admissibility maps, difficulty predictors, ROM compression and ACCELERATE results.

### 9. What changes for users and model builders?
Discuss provenance, reproducibility, restartability, inspectable components and separation of data handling from computation. Do not present research-stage capability as production-ready.

### 10. Current status
Regenerate close to submission from canonical evidence. Use four categories: available and qualified; implemented with qualification ongoing; in active development; research/future option. Do not infer status from code presence alone.

### 11. SWAP5, MultiSWAP and NHI terminology
Keep provisional until nomenclature and ownership are formally aligned. Distinguish SWAP, SWAP5, MetaSWAP, MultiSWAP, any fast-route component, MODFLOW 6 coupling and NHI adoption status. Do not invent equivalence among these names.

### 12. Outlook
List research questions and capability directions. The article may say the architecture enables research on coupling, scale, numerical robustness, drought response and computational feasibility. It must not answer those questions or preview quantitative results.

## Figures firewall

Safe figure classes: conceptual water-system diagram; public instrumentarium/context diagram; high-level SWAP5 component placement; qualitative component interaction; development-status schematic without publication-grade result data.

Protected figure classes: COUPLE response/convergence figures; q_bot/q_u/u diagrams encoding scientific interpretation; SCALE regime maps; P2 solver discrepancy/admissibility maps; DIFFICULTY predictor plots; NUM-UNC sensitivity/path-dependence plots; TRACE discrepancy matrices/taxonomies; ROM state-complexity/predictive-ambiguity curves; any figure already planned in an international manuscript.

Rule: if a figure could later serve unchanged, or nearly unchanged, as a central Results figure in an international paper, do not publish it in Stromingen first.

## Tables firewall

Safe: public component roles, terminology, broad development status and publicly documented software ecosystem.

Protected: benchmark results, solver comparisons, coupling response metrics, preservation/equivalence statistics, discrepancy counts, aggregation errors and performance data supporting an international conclusion.

## Wording rules

Prefer: wordt ontwikkeld om; maakt het mogelijk te onderzoeken; vereist afzonderlijke kwalificatie; is onderwerp van lopend onderzoek; de beoogde architectuur ondersteunt; op basis van de huidige kwalificatie, only when backed by exact authority.

Avoid: we tonen aan; blijkt dat; is superieur; werkt beter; is geldig zolang; kan zonder verlies worden vervangen; voorspelt; de nieuwe methode, unless already independently published and citation-safe.

## Submission-time checks

1. Reconcile this plan against the latest PUBLICATION_PROGRAMME.md.
2. Inventory all research lines created after this document.
3. Search every article figure and table against international manuscript plans.
4. Rebuild the current-status section from canonical evidence.
5. Verify SWAP5 / MultiSWAP / MetaSWAP / NHI terminology with current project authority.
6. Separate public facts from prospective architecture.
7. Check that no unpublished quantitative result is required to support the article thesis.
8. Ask of every strong claim which publication owns the primary inference.
9. If ownership is unclear, downgrade to context/question or omit.
10. After an international paper is published or accepted, consider a later Dutch follow-up in Stromingen for those results instead of leaking them into this overview.

## Provisional title

Preferred: Van SWAP naar een modulair hydrologisch instrumentarium: modernisering van de onverzadigde zone naast MODFLOW 6 en Ribasim

Alternative: SWAP in een nieuw modulair hydrologisch instrumentarium

Avoid titles implying that SWAP5, MODFLOW 6 and Ribasim together already constitute the formally adopted new NHI.

## Working article objective

The article should leave the Dutch hydrological reader with four things:

1. A clear picture of why the modelling environment is changing.
2. A correct understanding of where SWAP5 fits conceptually.
3. A realistic view of what is already established versus still under qualification or research.
4. Enough context to follow later international scientific publications without those publications having been pre-empted.