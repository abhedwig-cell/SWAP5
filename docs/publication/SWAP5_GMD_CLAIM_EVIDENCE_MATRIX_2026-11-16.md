# SWAP5 GMD claim–evidence matrix

Status: living pre-manuscript traceability matrix
Date: 2026-11-16
Companion: `SWAP5_GMD_MANUSCRIPT_SKELETON_2026-11-16.md`

Legend:
- READY: current repository evidence is already strong enough to support the bounded claim, subject to exact-release rerun/archive.
- PARTIAL: substantial evidence exists but paper-specific evidence or release decision is missing.
- BLOCKED: depends on unfinished capability/release work.
- OPTIONAL: not required for the reference paper.

| ID | Proposed bounded manuscript claim | Current evidence signal | Status | Paper-specific work still needed | Reserved novelty / warning |
|---|---|---|---|---|---|
| C01 | SWAP5 has a standalone user-executable no-macropore core that completes representative applications and restart | accepted no-macro release; standalone source build/run/restart; RC2 Windows/Ubuntu user qualification | READY | rerun/archive exact paper release and document supported build path | Do not call excluded macropore functionality complete |
| C02 | Representative original SWAP process families are present in the new execution architecture | recent admissions include ET/rain, heat, crop management, hysteresis, snow, sorption/decomposition, bottom laws, PCHIP/geometric means/Darcy evaporation, prescribed-head and soil-air/ceramic boundaries | PARTIAL | final capability matrix and compact E1 selection | Presence is not independent validation |
| C03 | SWAP5 preserves accepted physical state across restart for representative coupled processes | full Hupsel/Grassgrowth/Andelst trajectories; seasonal/daily restart; changed-state groundwater/Cauchy restart; hysteresis/snow state preservation | READY | create one publication-grade integrated E2 restart/conservation experiment | General transaction theory stays outside GMD |
| C04 | The release has explicit platform/build qualification rather than relying on one developer environment | no-macro RC2 Windows/Ubuntu qualification; GNU/source-bound arithmetic work | READY | exact release platform table and archived build instructions | Avoid claiming bitwise portability unless proved |
| C05 | Migration decisions distinguish preserved behaviour, corrected defects and explicit exclusions | numerous source assessments, corrections, refusals and retained failures; leaf-DM/dead-leaf correction; constitutive failures; legacy exclusions | PARTIAL | preregister E3 case selection and derive final denominator from closed coverage | TRACE owns general discrepancy claims |
| C06 | SWAP5 supports multiple independent model instances without state leakage | interleaved independent Andelst/Grassgrowth/Hupsel evidence and multi-column architecture | PARTIAL | release-specific population/state-isolation experiment | MultiSWAP scale claim requires E4 |
| C07 | Multi-column execution can be characterised at application scale | earlier MultiSWAP/SCHED/performance work | PARTIAL | clean E4 rerun with fixed hardware, model runtime separated from build/CI | ACCELERATE novelty excluded |
| C08 | SWAP5–MODFLOW6 can be described as a conservative coupled capability | coupling work exists, but paper-grade strip benchmark/release status not yet frozen | BLOCKED | complete/freeze F-GC-STRIP01 and exact coupling release scope | COUPLE owns general ownership/coupling theory |
| C09 | Hupsel is a complete representative SWAP5 application trajectory | verified 1096-day public Hupsel application; later complete water/solute route and restarts | READY | decide whether Hupsel is primary paper application; package public inputs and paper outputs | Do not overclaim validation against observations |
| C10 | Grassgrowth and Andelst provide additional long/complex application evidence | 1827-day Grassgrowth and 481-day Andelst trajectories plus restart/heat/crop evidence | READY | use as supporting evidence unless one is selected as primary application | Avoid three application narratives in main paper |
| C11 | Performance is measured with explicit scientific limitations | RC1 performance investigation; matched compiler controls; unsafe adaptive speedup rejected; SaltFarm qualification | READY | select only bounded release runtime/scaling results | No general speedup claim |
| C12 | Preferential-flow/macropore functionality can be excluded without blocking the core reference release | accepted no-macro release exists; original macro solver can run/restart, while day-438 coupled residual inconsistency remains scientifically unresolved | READY as scope decision | define exact release exclusion and limitation wording; ensure archived release cannot silently expose unqualified capability | Macropore scientific audit/paper remains separate |
| C13 | Original macropore behaviour is fully qualified | solver/run/restart evidence exists but day-438 blocker remains | BLOCKED | independent original-code audit and resolution if ever admitted | Do not hold GMD core paper hostage to this claim |
| C14 | Alternative fast solver/SSS is part of reference release | historical/experimental evidence only | OPTIONAL | include only after explicit release admission and applicability envelope | Otherwise omit |
| C15 | Ribasim is an implemented release capability | future/in-progress instrument direction, not established here as release capability | BLOCKED/OPTIONAL | only include if exact release has qualified interface | Otherwise discussion/future work only |
| C16 | The release can be reproduced from persistent source/data artifacts | repository provenance is strong but DOI release/reproduction package does not yet exist | BLOCKED | tag release; archive source and reproduction package with DOI; regenerate final figures/tables | Required before submission |

## Immediate evidence priorities

1. Freeze a paper-release capability/exclusion matrix as soon as release scope is stable.
2. Treat macropore as an explicit release-scope decision, not a hidden unfinished item.
3. Convert Hupsel into a candidate publication package because a complete public trajectory already exists.
4. Complete F-GC-STRIP01 only if MODFLOW6 coupling is intended in the first paper release.
5. Design E2 as one integrated conservation/restart experiment rather than many subsystem demonstrations.
6. Preserve exact negative evidence around macropore day-438, unsafe speedups and failed constitutive alternatives without forcing them into the main manuscript.
7. Do not create manuscript prose from READY claims until exact-release evidence can be regenerated.
