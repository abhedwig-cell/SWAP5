# Canonical open-PR reconciliation — 2026-09-19

Canonical authority at reconciliation: `integration/f-ci-canonical@1bc402b64ca216ba35af8e3a8ed58261550b5f25`.

## Scope

Bounded central-regie reconciliation of all open pull requests after the current production/application delta. No new hydrological physics, solver functionality, coupling method or ROM content is introduced here.

## Canonical resolutions executed

- PR #388 was merged as `13d1b9920e9f2e01e4e75f23c9a307c398f6e414`, reconciling moving preservation with the already admitted PPA-LOW02-TIME and PPA-ROOT-HYD01 successors. Its exact-head F-CI canonical qualification and targeted preservation workflow were green before merge.
- PR #390 was merged as `1bc402b64ca216ba35af8e3a8ed58261550b5f25`, refreshing PUB-GC E7 preservation through the latest production envelope. The E7/current-preservation, GMD pre-submission, documentation and live groundwater-service checks were green; its only pre-merge F-CI failure was the stale pre-#388 temporal-indicator preservation failure that #388 subsequently repaired.
- Superseded/stale historical PRs were closed with explicit reconciliation comments rather than silently discarded.

Closed in this reconciliation:
`#55 #56 #57 #59 #60 #61 #62 #63 #64 #65 #66 #67 #68 #69 #70 #71 #74 #90 #92 #93 #94 #95 #96 #97 #98 #99 #100 #102 #103 #112 #114 #124 #128 #129 #130 #133 #140 #141 #142 #156 #175 #221 #222 #223 #224 #225 #226 #227 #233 #234 #262 #341 #349 #352 #385`.

## Remaining open PR classification

| PR | Classification | Central-regie disposition |
|---|---|---|
| #58 | current and admissible | Intentional canonical carrier; keep open as draft against `main`. |
| #72 | evidence-only but still relevant | Status-A→AA governance files are not present byte-identical on current canonical. Keep open; explicit governance reconciliation required before any adoption. |
| #163 | evidence-only but still relevant | F-TB13 analytical-suite preservation is not represented by a current canonical F-TB13 status. Recompose before admission. |
| #172 | evidence-only but still relevant | Transaction/restart traceability remains relevant but branch is stale. Recompose against current test architecture. |
| #181 | current specialized publication work | Publication-owner surface. No central content action. |
| #187 | blocked | Reference calibration matrix is explicitly blocked. Keep as research evidence under publication ownership. |
| #199 | current specialized publication research | Preregistration/foundation of PUB-ME line. No central content action. |
| #207 | current specialized publication research | D2 evidence within PUB-ME line. No central content action. |
| #217 | current specialized publication research | D1–D6 adjudication line. No central content action. |
| #218 | current specialized publication research | F-CI98 successor replay. No central content action. |
| #219 | current specialized publication research | Physical replication line. No central content action. |
| #289 | current specialized ROM research | ROM ownership remains outside central regie. |
| #359 | current specialized publication tooling | GMD export hardening. Keep under publication ownership. |
| #361 | blocked | PPA-WU05-B frost authority remains blocked; current canonical does not resolve the held source/state authority. No production admission. |
| #363 | blocked / conflicting with newer authority context | PPA-WU05-D still lacks compensation-equation authority; additionally it must now bind the admitted PPA-ROOT-HYD01 root-sink temporal successor before any implementation. |
| #365 | current specialized research | DIFFICULTY preregistration. No central scientific action. |
| #366 | evidence-only but still relevant | HYDRO-MEMORY predecessor gate. Operational blocker picture has advanced through #378 and PPA-ROOT-HYD01 #387; retain under research ownership. |
| #370 | current specialized research | NUM-UNC preregistered research. No central scientific action. |
| #371 | blocked by stale-base reconciliation | PUB-GC finalization tooling remains useful but must be rebound to post-#388/#390 canonical/publication authority before merge. |
| #378 | blocked / evidence-only | HYDRO-MEMORY CAP01 diagnostic evidence. Keep under research ownership; regie does not reinterpret the scientific blocker. |
| #389 | current specialized publication work | Stromingen overview draft and firewall. No central content action. |

## Dependency map

- **Canonical preservation:** current moving-preservation authority includes exact PPA-LOW02-TIME backend and exact PPA-ROOT-HYD01 temporal-indicator successors via #388.
- **PPA-WU05:** WU05-C is canonically closed via #354/#356. WU05-B (#361) remains blocked. WU05-D (#363) requires authority refresh against PPA-ROOT-HYD01 before implementation.
- **RossFast:** live authority is the later admitted F-ROSS12/F-ROSS13/F-CI107/F-ROSS22 lineage plus subsequent characterization/closure evidence; the old #221–#227 and #128–#142 stacks are historical only.
- **Groundwater coupling:** F-GC26 is canonically closed; F-GC49 is closed through Stage D. Further coupling-product work remains owned by the dedicated coupling workstream.
- **Publication:** PUB-GC E7 preservation is refreshed through #390. #371 still needs stale-base rebinding. Research/preregistration PRs stay under their publication owners.
- **Governance/test preservation:** #72, #163 and #172 are the three remaining old branches that still contain potentially useful evidence not directly represented by their own current-canonical status records. They require deliberate reconciliation, not blind merge or closure.

## Central-regie boundary

No `src/**` feature code was developed by this reconciliation. Specialized production, solver, coupling, ROM and scientific-publication ownership remains unchanged.
