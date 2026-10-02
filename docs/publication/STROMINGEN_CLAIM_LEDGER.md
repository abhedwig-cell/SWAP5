# Stromingen claim ledger

Date: 2026-09-19
Purpose: sentence-level publication control for the Dutch overview article.

Each claim classifies what the manuscript is allowed to assert before submission. This ledger is not a scientific evidence ledger; it prevents context statements from drifting into claims owned by international papers.

| ID | Section | Allowed claim | Evidence class | Protected owner / risk | Status |
| --- | --- | --- | --- | --- | --- |
| ST-C01 | 1 | Dutch hydrological applications span atmosphere/vegetation, unsaturated zone, groundwater and surface water/water allocation | general hydrological context | none | GREEN |
| ST-C02 | 1 | Public NHI tooling includes MODFLOW 6/iMOD, iMOD Coupler and Ribasim developments | public external source | nomenclature/currentness | GREEN, reverify before submission |
| ST-C03 | 1 | The instrumentarium trend is toward more explicitly coupled specialized components | synthesis of public context | avoid claiming formal adopted architecture | GREEN/AMBER |
| ST-C04 | 2 | SWAP has a long process-based modelling history and was discussed in the 50-year Stromingen article | published source | none | GREEN |
| ST-C05 | 2 | Modern model environments place greater demands on reproducibility, testing and coupling than historical standalone execution | general context | P1 if converted into method/novelty | GREEN/AMBER |
| ST-C06 | 2 | Public NHI communication positions MultiSWAP as successor to MetaSWAP and links the development to SWAP | public external source | nomenclature | GREEN, reverify |
| ST-C07 | 3 | SWAP5 modernizes the SWAP model basis and separates scientific computation more clearly from data handling/execution/coupling | repository/project context | P1 | AMBER, keep high-level |
| ST-C08 | 3 | SWAP5 is developed and qualified incrementally using reference cases and automated quality controls | repository context | P1/TRACE | AMBER, no method/result detail |
| ST-C09 | 3 | Code presence is not equivalent to qualified production capability | project governance principle | P1/TRACE | GREEN if descriptive |
| ST-C10 | 4 | Unsaturated-zone and groundwater components exchange boundary/state/flux information in coupled simulation | general hydrology/coupling context | PUB-GC | GREEN at generic level |
| ST-C11 | 4 | The exact coupling variables, interval handling and numerical strategy require separate qualification | generic method statement | PUB-GC | AMBER, no specifics |
| ST-C12 | 4/6 | Different model components may use different spatial and temporal representations | general context | PUB-SG | GREEN |
| ST-C13 | 4/6 | Technical coupling alone does not establish representativeness for a given application | generic scientific caution | PUB-SG | AMBER, no validity criteria |
| ST-C14 | 5 | MODFLOW 6 is used as groundwater engine within current NHI/iMOD developments | public external source | currentness | GREEN, reverify |
| ST-C15 | 5 | Ribasim addresses surface-water balance/network/allocation functions and is part of current NHI development | public external source | currentness | GREEN, reverify |
| ST-C16 | 5 | SWAP5, MultiSWAP and MetaSWAP must not be treated as synonyms without formal authority | nomenclature control | organizational | GREEN |
| ST-C17 | 7 | Scientific model functionality requires qualification beyond technical implementation | generic scientific-software principle | P1/TRACE | GREEN if generic |
| ST-C18 | 7 | Quality control may include tests, reference cases and balance checks | generic/project context | P1/TRACE | GREEN/AMBER, no taxonomy or superiority claim |
| ST-C19 | 8 | Computational cost matters for regional/large-scale applications | general context/public NHI motivation | P2/F-ROM | GREEN |
| ST-C20 | 8 | Alternative computational routes require validation for intended use | generic statement | P2 | AMBER, no admissibility-domain framing |
| ST-C21 | 9 | Modular component boundaries can support maintainability, provenance and targeted testing | design context | P1 | GREEN/AMBER, avoid claiming evaluated benefit |
| ST-C22 | 10 | Status must distinguish qualified, qualification ongoing, active development and research/future | governance convention | all | GREEN |
| ST-C23 | 10 | Current SWAP5 status must be rebuilt from then-current canonical authority at submission | repository authority | all | MANDATORY |
| ST-C24 | 11 | Coupling, scale, numerical robustness, drought response and computational feasibility remain broad research themes | thematic outlook only | PUB-GC/PUB-SG/P2/HYDRO-MEMORY/DIFFICULTY/NUM-UNC/F-ROM | AMBER, no near-final RQs |
| ST-C25 | 11 | Technical feasibility must not be equated with hydrological validity | generic closing principle | multiple | GREEN/AMBER |
| ST-C26 | current status | Reference Richards, committed-boundary restart and serialized real-physics MultiSWAP are qualified current production capabilities | current canonical PPA/capability authority | P1/P2 only if expanded into evidence/results | GREEN as status fact |
| ST-C27 | current status | A bounded live SWAP5-MODFLOW 6 production-oriented coupling chain is qualified, while actual iMOD Coupler product-driver integration remains separate | post-Status-A groundwater authority / PPA audit | PUB-GC | GREEN/AMBER: status only, no coupling science |
| ST-C28 | current status | Several advanced legacy process/input families are not yet broad normal SWAP5 production routes | current canonical PPA audit | TRACE / future migration lines | GREEN as scope limitation |

## Prohibited claim forms before international publication

Do not add claims of the form:
- 'we demonstrate that...';
- 'the experiments show...';
- 'the valid domain is...';
- 'the solver is faster by...';
- 'numerical difficulty can be predicted from...';
- 'aggregation remains valid until...';
- 'groundwater memory occurs when...';
- 'these discrepancy classes were found...';
- 'the coupling converges for...';
- 'a compact state of dimension ... is sufficient...'.

## Evidence policy

Public facts about NHI, iMOD, MODFLOW 6, Ribasim and published SWAP history require external citations and must be refreshed before submission.

Statements about current SWAP5 capability require exact current repository qualification authority.

Statements classified AMBER should remain qualitative. If the manuscript needs a quantitative statement to make an AMBER claim persuasive, that is a signal that the claim probably belongs in the owning international paper instead.

## Change-control rule

Any new paragraph added to the manuscript should either map to an existing ST-C claim or add a new claim here before manuscript merge. Any new figure/table requires the equivalent check in STROMINGEN_FIGURE_PLAN.md.