# Stromingen figure plan and publication firewall

Date: 2026-09-19
Branch: docs/pub-stromingen-firewall-outline

## Principle

The Stromingen article should use explanatory figures, not evidence figures.

A safe figure helps a reader understand system context, component roles, terminology or development status. A protected figure supports a scientific inference, quantifies a regime, demonstrates equivalence, compares methods or could later function as a Results figure in an international manuscript.

Hard rule:

> If a figure could be reused with only cosmetic changes as a central Results or Methods figure in P1, P2, PUB-GC, PUB-SG, PUB-RC, F-ROM, HYDRO-MEMORY, DIFFICULTY, NUM-UNC or TRACE, it does not belong in this Stromingen article.

## Figure 1: The hydrological system and model domains

Status: SAFE.

Purpose:
- orient the reader hydrologically before software is discussed;
- show atmosphere/vegetation, unsaturated zone, groundwater, and surface water/water allocation;
- associate SWAP/SWAP5, MODFLOW 6 and Ribasim only at a high conceptual level.

Recommended visual:
- a cross-section or conceptual vertical system;
- atmosphere and vegetation at top;
- unsaturated zone below;
- groundwater below/adjacent;
- surface-water network at side;
- simple arrows for water exchange;
- labels for relevant model families.

Must not contain:
- q_bot/q_u/u notation;
- coupling-window semantics;
- response derivatives;
- N:1 mapping logic;
- solver names;
- regime thresholds;
- any result.

Publication owners protected: PUB-GC, PUB-SG, HYDRO-MEMORY.

## Figure 2: From standalone model to modular instrumentarium

Status: SAFE WITH CONSTRAINTS.

Purpose:
- explain the organizational shift without publishing P1 architecture.

Recommended visual:
Left: a standalone SWAP application represented as one box receiving input and producing output.
Right: a modular setting with separate high-level boxes for SWAP5, MODFLOW 6 and Ribasim connected through a generic coupling layer or exchange arrows.

Keep labels generic:
- model core;
- input/output;
- coupling;
- model configuration.

Must not contain:
- authoritative-state ownership;
- trial/accepted/committed states;
- rollback/retry;
- interval transaction lifecycle;
- commit/publication ordering;
- detailed internal class/module structure.

Publication owners protected: P1 and PUB-GC.

## Figure 3: Public Dutch instrumentarium context

Status: SAFE IF SOURCE-BASED.

Purpose:
- distinguish current/publicly documented elements from project-specific development;
- help readers understand MetaSWAP, MultiSWAP, SWAP5, MODFLOW 6, Ribasim and iMOD Coupler terminology.

Recommended visual:
A terminology/context diagram with categories such as:
- current publicly documented NHI software;
- successor/development line;
- SWAP5 model-basis modernization;
- coupling/tooling context.

Critical constraint:
The figure must be rebuilt immediately before submission from then-current NHI/Deltares/WENR public authority. It must not infer that SWAP5 equals MultiSWAP or that a specific SWAP5-MODFLOW6-Ribasim production architecture has formally been adopted unless that is explicitly documented.

Publication owners protected: all; main risk is organizational overclaim rather than novelty leakage.

## Figure 4: Development and qualification status

Status: SAFE IF EVIDENCE-BOUND.

Purpose:
- make the difference between implemented, qualified and future capability understandable.

Recommended visual:
Four columns or lanes:
1. available and qualified;
2. implemented, qualification ongoing;
3. active development;
4. research / future option.

Content rule:
Every item must have a current authority source. Presence in source code or a feature branch is insufficient.

Must not contain:
- experimental metrics;
- solver/coupling comparisons;
- evidence counts that support P1 or TRACE;
- readiness inferred from branch names.

Publication owners protected: P1, P2, PUB-GC, TRACE.

## Optional Figure 5: Why component scale matters

Status: OPTIONAL, HIGHER RISK.

Use only if the text otherwise feels too abstract.

Safe form:
- show three different generic discretizations: local vertical column, groundwater grid, surface-water network;
- caption only that components can operate on different spatial representations.

Do not show:
- equivalent-column construction;
- aggregation formulas;
- mapping weights;
- 1:N or N:1 experiment design;
- error arrows, thresholds or validity envelopes.

Publication owner protected: PUB-SG / SCALE.

Recommendation: omit this figure unless the editor or co-authors think the scale issue is difficult to understand from prose.

## Figures explicitly reserved for international papers

Do not create for Stromingen:
- P1 migration/preservation workflow with transactional semantics;
- state ownership or retry/rollback diagrams that carry the P1 method;
- RossFast versus Richards performance or discrepancy figures;
- solver-admissibility or exclusion-domain maps;
- numerical-difficulty predictor plots;
- coupling response curves or head/flux closure plots;
- q_bot/q_u/u interpretation diagrams if they carry PUB-GC scientific semantics;
- coupling-window/convergence plots;
- supplied-response versus secant/Aitken comparisons;
- aggregation/transferability/regime maps;
- ROM state-complexity versus predictive-ambiguity plots;
- drought-memory regime plots;
- numerical-uncertainty/path-dependence plots;
- TRACE theory-documentation-code-evidence matrices if used as a novel method or empirical taxonomy.

## Recommended final figure set

For a first submission, use four figures only:

1. Hydrological system and model domains.
2. Standalone model versus modular instrumentarium.
3. Dutch instrumentarium / terminology context.
4. Current development and qualification status.

This set is sufficient for Stromingen and deliberately avoids scientific Results figures.

## Caption rule

Captions must be descriptive rather than inferential.

Prefer:
- 'Schematic position of the main model domains discussed in this article.'
- 'Conceptual transition from standalone execution to a modular model environment.'

Avoid:
- 'This shows that...'
- 'The architecture guarantees...'
- 'Aggregation remains valid when...'
- 'The new solver is faster...'
- 'The coupling converges because...'

## Final pre-submission figure audit

For every figure:
1. identify its source material;
2. identify any paper owner whose claim it touches;
3. state whether the figure conveys context, method or result;
4. reject it if it conveys an unpublished method/result owned elsewhere;
5. verify nomenclature and readiness claims against current authority;
6. ensure the figure can be understood without unpublished repository evidence.