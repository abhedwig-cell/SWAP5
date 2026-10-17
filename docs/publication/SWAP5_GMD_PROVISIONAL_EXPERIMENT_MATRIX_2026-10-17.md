# SWAP5 GMD provisional paper experiment matrix

Status: provisional; experiment-selection aid, not a release or admission gate
Date: 2026-10-17
Parent policy: `docs/publication/SWAP5_GMD_PUBLICATION_READINESS_SPEC.md`

## Purpose
Select a small number of interpretable experiment families that can carry a future GMD SWAP5 reference paper. The complete capability ledger remains underlying evidence; the paper suite should demonstrate the model with a few strong experiments. No selection is final before release-scope freeze.

## Matrix

| ID | Paper claim | Provisional experiment | Evidence to mine | Missing before paper freeze | Firewall |
|---|---|---|---|---|---|
| GMD-E1 | Core process physics is represented and qualified across representative regimes | Compact constitutive/process benchmark plus selected atmosphere–root–soil responses | 12-model hydraulic testbank; admitted crop/root/weather/oxygen routes | select small representative panel; regenerate against exact release | No exhaustive feature catalogue; regression is not validation |
| GMD-E2 | Multiple processes operate on one accepted physical state with conservative continuation | Integrated water + crop/root + solute/N trajectory with non-trivial restart | accepted Richards/crop/root; NH4/NO3/reactive N; solute/water-age; pond mass; irrigation restart evidence | one clean trajectory with explicit water, solute and N budgets and restart oracle | General transaction theory stays outside GMD |
| GMD-E3 | SWAP4.3.1 migration was reconciliatory rather than blind copying | Bounded lineage set: preserved behaviour, intentional correction/source defect, explicit exclusion/supersession | mastercoverage; source assessments; dead-leaf/leaf-DM correction; lower-boundary exclusions | preregister case selection; quantify final denominator | General discrepancy taxonomy belongs to TRACE |
| GMD-E4 | The same model executes many isolated columns at application scale | Heterogeneous MultiSWAP population with deterministic aggregation and measured scaling | MULTI/SCHED/performance evidence | clean release rerun, fixed hardware and no build/CI contamination | No general acceleration/solver-policy novelty |
| GMD-E5 | SWAP5–MODFLOW6 exchange is conservative and physically interpretable | F-GC-STRIP01: analytical MODFLOW → drain-down → coupled simple forcing → Hupsel | strip/coupling contracts and historical tests | freeze parameters; Dupuit oracle; release-qualified balances and figures | Do not require SWAP GWL = MODFLOW head; general coupling theory stays COUPLE |
| GMD-E6 | Released model behaves interpretabily in a realistic heterogeneous application | One application case, candidate Hupsel or regional case | Hupsel and regional experience | select after release scope; prefer archivable data and independent observations/oracles | Do not overclaim validation |
| GMD-E7 | Optional fast/alternative routes have explicit bounded status | Only if a route such as SSS is sufficiently qualified in the release | SSS/solver evidence where applicable | defensible applicability envelope | Optional; exclude rather than weaken paper |

## Integration rule
E1 and E2 should carry most process breadth. Do not create separate paper experiments just because irrigation, drainage, nutrients, solutes, crop lifecycle, macropores or another subsystem has its own migration workstream.

## Current judgement
High confidence: E1, E2, E5.
Medium confidence: E3, E4, E6.
Conditional: E7.

## Evidence capture
For unusually clean E1–E7 evidence preserve exact SHA, executable input, machine-readable output, independent oracle, balance terms, analysis script, accepted/rejected state semantics where relevant, and negative/applicability evidence. Do not modify scientific admission criteria to serve publication.

## Freeze decision
Final selection only after functional coverage closes, release exclusions and coupling scope are known, datasets can be archived, and reproduction runtime is feasible. Then convert this matrix into readiness gate G3.
