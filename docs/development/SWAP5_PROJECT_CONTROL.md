# SWAP5 Project Control

**Work unit:** PROJECT-CONTROL-01  
**Control snapshot:** `integration/f-ci-canonical@1b15bbb4b01135a93150d28aad3461890af90542`  
**Date:** 2026-09-20  
**Machine-readable authority:** `integration/control/SWAP5_WORKSTREAM_REGISTRY.json`

## Purpose

This page is the single human-readable routing map for the live SWAP5 programme.

It does **not** replace scientific, implementation or qualification evidence in the owning workstreams. It answers a smaller set of control questions:

1. Which workstream owns the next action?
2. What is the latest canonical authority that workstream must bind?
3. Is the line active, blocked, owner-controlled, or waiting for central reconciliation?
4. Which open PRs are live work, which are historical/superseded, and which are blocked?
5. What must return to central regie before it may alter canonical authority?

The canonical branch moves quickly. This document is therefore an **exact snapshot**, not a claim that the branch remains at this SHA. Before a central admission action, reconcile the delta from the snapshot head to the live canonical head.

## Integration refresh 2026-10-11

Central regie reconciled the live queue from `c7879cdf54fce43d668877f5a0a4d71806df7426` and established the latest verified recovery point `integration/f-ci-canonical@44a031a83b5b9da5f8a76e4e8859396e57a48cd0`. The original 2026-09-20 control snapshot below remains historical evidence; this refresh is the current delta authority.

### Canonical admission completed

MC-IRR01 was recomposed from its qualified isolated owner postimage and admitted through PR #1195. The admitted production and test blobs match qualified integration head `4ed0a6d62eae82f46d9f79d06b764e141474c9e2`. Central regie added no new production physics, only exact bounded preservation and admission metadata.

- owner gate: F-APP07 run `38115056270`, O0/O2 PASS;
- canonical preservation: F-CI run `38115056145`, all frozen jobs plus moving-current job `114398715430` PASS;
- admission head: `4ed4fa44c05b93c44d53c2f62a97d2307e29cca9`;
- canonical squash merge: `cadcc63d3296e12e6a0634ee7095693454b60005`.

The moving functional-coverage master remains independently owned by PR #1072. It must recompute from the admitted canonical postimage before publishing fresh global counts. The MC-IRR01 admission is bounded and is not a claim of unrestricted irrigation coverage.

F-PE-NLGLOB14Z47 was then selectively recomposed from its qualified historical owner result on current canonical and admitted through PR #921. Only the fail-closed eligibility guard for the already-admitted, explicit non-default moving-interface manager was admitted. The historical cumulative research lineage was not imported; `LEGACY_NUMERICS` remains the production default.

- reconciled PR head: `c7c5bf65d812f236f7c5005c396b5c1c8b02c457`;
- exact admitted tree: `c209b72768639df6fb4e3ed833f843d50da46fb3`;
- qualified manager postimage: `fc3805e1f106b5de1ee3a492920d0c21eba7bd1d`;
- exact F-CI preservation script: `327b29a207a2e6346220b11682c963f90ded1a2a`;
- historical focused owner authority: run `36818047308`, job `110227325151`, SUCCESS;
- reconciled PR preservation: F-CI run `38119253100`, moving-current job `114410923144`, PASS;
- canonical squash merge: `44a031a83b5b9da5f8a76e4e8859396e57a48cd0`;
- canonical verification: F-CI run `38119657018`, moving-current job `114411818086`, PASS.

Central regie added no production physics and did not activate the manager by default. The owner gate executes at O0 and O2 and requires byte-identical output; the canonical preservation authority pins the complete 40-character manager blob.

### Supersession closures

Sixteen PRs were closed only after their successor and recovery path were recorded in the PR thread:

- exact canonical ancestors: #1073, #1074, #1075, #1076, #623, #624 and #625;
- duplicate or narrower candidates superseded by unified admissions: #1104, #1111, #1113, #1122 and #1129;
- stale central checkpoints/probes: #1121 and #1105;
- obsolete irrigation carriers superseded by MC-IRR01: #1097 and #1126.

A second batch closed 31 already-consumed or superseded candidates after exact-head evidence was recorded in every PR thread:

- F-CI110 / PR #626 performance reconstruction: #599, #600, #601, #604, #607, #608, #610, #617, #618, #619, #620 and #621;
- F-PE-SYSTEM-CLOSE01 current-host performance closeout: #669, #671, #672, #673, #674, #675, #676, #677, #678, #679, #680 and #686;
- admitted ELASTIC successors: #807, #822, #891 and #910;
- bounded PPA-WU05-C3A successor PR #962: #973;
- canonical issue-#989 storage-ownership fix: #990 and #995.

A third batch closed 17 completed historical performance/research carriers with their exact heads and selected successors preserved:

- F-CI110 / F-PE-SYSTEM-CLOSE01: #602, #605, #609, #611, #612, #613, #614, #615 and #616;
- selected REPAIR01/PROFILE05R2/PROFILE06 successors: #634, #635, #636 and #639;
- completed negative or observation-only F-PE-SYSTEM-CLOSE01 evidence: #654, #657, #658 and #659.

After canonical admission of #921, 15 cumulative NLGLOB research candidates were closed as superseded live candidates: #810, #830, #841, #844, #849, #852, #856, #859, #861, #867, #872, #876, #879, #880 and #882. Each PR thread records its exact research head and points to #921 / `44a031a83b5b9da5f8a76e4e8859396e57a48cd0`. Their negative, falsification and unselected research evidence remains reachable; closure does not declare that research lineage admitted.

PR #58 remains the intentional canonical carrier. After both admissions and all 79 supersession closures in this reconciliation, exactly 54 PRs remain open. This count was read from the live GitHub queue after the #921 merge and NLGLOB closure batch; it is descriptive, not a replacement queue authority.

### Exact remaining blockers and owners

| PR | Owner | Required resolution |
|---|---|---|
| #1120 | CI/workflow governance | Replace incomplete static PR path filters with a generated/conservative dependency surface or fail-closed trigger strategy. Observed compile closure exceeds the proposed lists: CO2 13 resolved paths for 3 owned sources; root runtime about 169 dependencies for 4 named sources. |
| #1083 | PPA-WU03/runon | Recompose the bounded delta on current canonical and replace the stale protected task2 pin and broad B19/MICRO tree assumptions with bounded successors. |
| #1119 | PPA-WU05B frost | Keep focused finite-guard work under the frost owner; recompose broad whole-source/exact-tree preservation against current canonical. |
| #1103 | HYD/HYST | Finish the active specialized qualification; no central semantics change or admission claim. |
| #1098, #1117 | NUT/SOL | Complete owner-controlled consolidated qualification and source/restart gates; #1117 is not an admission proposal. |
| #1072 | functional-coverage master | Recompute from canonical `44a031a83` and incorporate bounded MC-IRR01 plus selective NLGLOB14Z47 before fresh global coverage counts. |
| #486 | F-GC shared admission authority | Resolve non-overlapping storage partition and one owner per physical drainage path. |

PRs #1196 (MC-HEAT01) and #1197 (MC-CROP01), together with the active PPA/macropore, frost, crop, nutrient/solute, hydraulics and coupling lines, remain with their specialized owners and were not modified by this integration round.

No manual workflow dispatches were added. Only path-triggered owner/preservation runs were used, and the necessary PR and canonical F-CI runs were polled to terminal success. Broad unrelated workflow results are not admission evidence; the exact owner and canonical-preservation gates named above are authoritative.

### Final preservation diagnostics

The control postimage `7ceb5ff0d66fa93c5b0e179c85c66b85ee5e6c40` passed canonical F-CI run `38120232542` (moving-current job `114413534831`) and F-GC fixed-interface run `38120232503`. Two additional historical preservation workflows failed and remain explicit owner/admission-authority debt, not positive admission evidence:

| Workflow / run / job | Exact blocker | Owner and next action |
|---|---|---|
| F-CI51P / `38120232502` / `114413253495` | WOF43A provider pin expects `1234bcb8e3b47ebe8e67b0bac6af35e09e9056da`; current provider is `040299d7fac3499f5b72f3b166cb08973530885d`. Rate-table dependency remains the pinned `5a0e8387157c5d1e1a6a94a24c19c7519c6bfcd5`. | F-CI central preservation authority with crop/MC-CROP owner: reconcile the admitted crop successor and its qualification before changing a preservation pin. |
| F-CI58P / F-CI93 / `38120232531` / `114413253835` | Historical authorities, successor lineage and M1-C3 receipt pass, then `M1-C3 Task2 successor blob drift`: expected `0406d3180262b06a5a393b605cc553a912a26aa0`, actual `2a17e9a203a9fc257550e2a9036f3f918421235e`. Downstream reconciliation job is skipped. | F-CI central preservation authority with Task2/PPA-WU03 owner: qualify and bind the admitted runon successor without replaying an older Task2 source. |

All three actual production blobs above are identical at pre-admission base `e3b9685470639355e1899b95c25f9a7ddee15fe6`, #921 merge `44a031a83b5b9da5f8a76e4e8859396e57a48cd0` and control postimage `7ceb5ff0d66fa93c5b0e179c85c66b85ee5e6c40`. These failures therefore predate the selective #921 admission and control refresh. This round records the debt but does not weaken either guard, authorize a successor implicitly, or modify active crop/Task2 implementation.

## Control model

### Preservation follow-up 2026-10-11

Central regie reconciled the qualified crop CO2 successor `75114770c4d4d300f9d8037207d5498fa0e1f44e` against canonical `4fab8a28a5a834844b8f9ffb105ff7185a95018c`. F-CI51P now retains the historical exact provider/dependency authorities while requiring exact admitted successor identity and replaying original WOF43A owner plus F-VQ37 independent semantics (29,000 cases and 13 edges), and the added CO2 semantics, at O0/O2 with output identity. All local gates passed. The original F-CI51 post-admission route delegates to that same preservation guard instead of retaining a contradictory old moving provider pin. No production/reference source, scientific assertion or tolerance changed. Exact-postimage automatic canonical qualification remains the final published gate; consult the commit-bound runs.

F-CI93 is **not repaired or admitted**. Initial diagnostic recovery `78bc8fc2c2ae34d6643c6eab3e5f943f54d91c53` reconciled RUNON/MIGMAC11/D2 and exposed the headed failure. Definitive contract diagnosis at canonical baseline `24a69ee415366c4c9d508806bd48bf14c002ea86`, recovery `85866972d3e2ea2dff835b955f73ae1009d02006` on `diagnosis/fci93-headed-contract-20261011`, reproduces it at both O0 and O2. HeadCalc requires a derivative receipt for every dynamic headed route; the provider supplies pond/runoff derivatives only with fixed top-node K, which Task2 binds only on M1. Paired provider probes are O0/O2 byte-identical and show a nonzero derivative and the missing non-M1 receipt. The immutable SWBOTB=2 F-KT15 fixture is not disproved; forcing M1 changes its physics and is not a preservation repair. Central HeadCalc/dynamic-top admission authority with Task2/PPA-WU03/MIGMAC owners must select and qualify a bounded derivative binding repair, preserving original surface/Task2/dispatch, mass/retry/restart and BOFEK/MIGMAC evidence. Exact source identities, commands and results are in `integration/f-ci/F-CI93_STATUS.json`, `headed_contract_diagnosis_20261011`. Production/reference/workflows and the canonical F-CI93 runner remain unchanged; no new Actions runs or semantic admission are claimed.

**Final bounded closeout:** exact canonical code postimage `491236f87d713f97a6ea809a241b066bb717b761` passed F-CI run `38121781430` (all 14 frozen jobs and moving-current job `114418101477`) and repaired F-CI51P run `38121781333`, job `114417817024`. Crop preservation is closed. The final receipt updates documentation/status only, carries exact unchanged code/workflow qualification, and uses `[skip ci]` to avoid repeating those gates.

F-GC closeout run `38121781326`, job `114417816972`, failed after PPA-WU01 bootstrap owner O0/O2 passed: FloPy `get_modflow` release retrieval returned `HTTP Error 403: rate limit exceeded`. The production/reference and F-GC workflow/runner blobs are unchanged from previous green run `38120739493`; this is external executable-provisioning failure, not a scientific regression claim, and the remaining full closeout was not completed. F-GC CI/provisioning owns the authorized route restoration. No duplicate rerun or permission workaround was attempted. Documentation source checks and JSON validation pass; strict MkDocs was not executed because the local environment lacks the module.

Specialized workstreams may research, implement and qualify inside their declared ownership. They do not acquire canonical authority merely by producing a branch or PR.

The common admission path is:

`READY_FOR_REGIE -> RECONCILE -> ADMIT | RETURN | SUPERSEDE`

Central regie owns canonical admission, cross-workstream supersession, shared-authority reconciliation, preservation repair and repository-level routing. Central regie does not develop new hydrological physics, solver functionality, groundwater coupling methods or production ROM functionality.

## Current project map

| Workstream | State | Current authority / finding | Next gate |
|---|---|---|---|
| REGIE | ACTIVE | canonical snapshot `1b15bbb`; PR #58 remains the intentional carrier; the old #72/#163/#172 housekeeping queue is closed; #486 is blocked shared-authority repair, not admission-ready work | Event-driven only: qualified specialized admission, preservation drift, shared-authority resolution, or deliberate control refresh |
| PPA production physics | ACTIVE | WU04-A Black, ROOT-HYD02 prescribed-root tangent and WU04-B Boesten are already merged to canonical; WU05-A/C are review-only authority | Production owner selects the next source-authorized bounded slice; no inference from review authority to production |
| F-GC groundwater coupling | BLOCKED_INTERNAL_AUTHORITY | F-GC50 remains externally blocked at product integration; PR #486 completed the semantic audit and bounded CSR-01/02 repair but broad admission is blocked by storage-partition and drainage-ownership authority | Resolve CSR-B1 storage partition and CSR-B2 drainage ownership before production admission or Hupsel rerun |
| F-ROM / LARE | BLOCKED_EXTERNAL | F-ROM-CODEMAP-01 is canonical: FMC remains source-authority blocked for contact/native ET; LARE has a bounded relative cost-fidelity signal but lacks external groundwater application-accuracy authority | Continue FMC and LARE as distinct research lines; return only bounded evidence successors, never the large LARE branch wholesale |
| HYDRO-MEMORY | ACTIVE | live root-active SWAP-MODFLOW6 passed one window and four consecutive windows; DYN01 forcing + state-dependent Feddes composition passed | Stage 0 remains unauthorized; continue remaining dynamic composition and soil/diagnostic freeze under research ownership |
| DIFFICULTY | OWNER_CONTROLLED | Phase-0 preregistration exists in PR #365 | Continue prospective research; independent nonlinear-method comparison remains separately gated |
| TRACE | ACTIVE | protocol, candidate register, Batch 02 closeout and Batch 03 are canonical | Continue prospectively; feed only shared governance implications back to regie |
| Publications | OWNER_CONTROLLED | canonical E7 still carries the prior component-domain result, but PR #486 places that interpretation under semantic review and holds submission if admitted | Reconcile publication tooling to current canonical and coupling authority; explicit archive/release metadata remains separate |

## Important current distinctions

### Production physics

Three items that can easily be misread from their status files are already canonical:

- PPA-WU04-A, PR #395, merge `50e7d1dece5b75d0103459d5c118d03a2665eea3`;
- PPA-ROOT-HYD02, PR #397, merge `7ea315285904783225741b350be292974afeec92`;
- PPA-WU04-B, PR #404, merge `4d40b8d4b6a1df06ff97fab55497542778431290`.

Some local status/result text still says “ready for canonical admission”. That wording is stale relative to the actual merged authority and should be treated as **evidence-freshness debt**, not as a rollback of the merged admission.

Advanced WU05 families remain different:

- WU05-A macropore authority is closed as review authority only; production is held pending exact source materialization and a complete mutable-state/mass census.
- WU05-C oxygen authority is closed as review authority only.
- WU05-B frost remains blocked.
- WU05-D compensated root uptake remains blocked and must refresh against later root-hydraulic authority before implementation.

### Groundwater coupling

There are now two separate coupling control questions and they must not be conflated.

**F-GC50 product integration** remains canonically `CANONICAL_INTERNAL_READY_EXTERNAL_B1_BLOCKED`: the remaining product-integration blocker is an authorized upstream iMOD Coupler driver/config extension route.

**PR #486 F-GC CSR** is a newer, noncanonical shared-authority repair candidate. Its authority audit identifies a distinct interpretation/application-binding defect: `SWBOTB=5` is prescribed pressure head at the lower SWAP boundary and may be used privately by the Reference backend to realize a trial interface head, but it is not itself the application-level authority for coupled groundwater. The candidate introduces explicit `groundwater_coupled` application authority and removes the application-level dependence on `bottom_mode==5`.

PR #486 is still in `CSR01_CSR02_IMPLEMENTED_QUALIFICATION_IN_PROGRESS`. It changes production source and therefore is not admitted by this control workstream. Its branch explicitly holds PUB-GC submission and requires coupling-assumption-dependent E6/E7 requalification if the repair is admitted. No Hupsel rerun is authorized by the candidate itself.

HYDRO-MEMORY live coupling evidence does not by itself settle either the F-GC50 product-integration boundary or the PR #486 semantic repair.

### ROM

The live ROM control authority now includes **F-ROM-CODEMAP-01**, admitted through PR #489, in addition to F-ROMV2.

The key routing split is explicit:

- **FMC / F-ROMV2** remains blocked on implementation authority for natural surface-front/groundwater-front contact and native ET/root-withdrawal composite-state updates.
- **LARE** has a branch-local bounded relative cost-fidelity signal, but application acceptance cannot be adjudicated without a real project groundwater head/drawdown error requirement and independently governed temporal error allocation.

Therefore there is still no production ROM and no permission to merge the large LARE research branch wholesale.

### HYDRO-MEMORY

The old CAP-gate PRs no longer describe the complete live state.

Canonical now contains:

- ACC02-F1: live root-active single-window coupling PASS;
- ACC02-F2: four consecutive live root-active windows PASS;
- DYN01: forcing plus accepted-state-dependent restricted Feddes composition PASS.

This is substantial research capability evidence, but **Stage 0 is still not authorized** and this research route does not silently widen the production application owner.

## Open PR routing

### Blocked shared-authority repair

- **#486 F-GC CSR** has completed its semantic classification and bounded CSR-01/CSR-02 repair, but its own current status says **do not merge yet**. The remaining blockers are `CSR-B1-STORAGE-PARTITION` and `CSR-B2-DRAINAGE-OWNERSHIP`. PUB-GC submission remains held and no Hupsel rerun is authorized. The repair is therefore no longer a generic “watch” item waiting on routine CI; it is blocked on explicit scientific/application authority.

### Central reconciliation queue

PR #72 has now been recomposed into current governance by GOV-REC01. The stale branch is not a merge target and should be closed after this successor is canonically admitted.

F-TB13R is now canonically admitted and historical PR #163 is closed.

F-TA04R is canonically admitted through PR #492 and historical PR #172 is closed. The old central #72/#163/#172 housekeeping queue is now empty. No new generic cleanup queue should be invented merely to keep central regie busy.

### Testbank preservation

F-TB13R is an additive current-canonical rebase of the qualified analytical/reference package from PR #163. Its preserved archive, member identities, replay receipt and checker are imported unchanged; a new reconciliation record binds them to current B1.11 and requires fresh dedicated F-TB13, Documentation, VQ and F-CI qualification. It does not rewrite F-TB11/F-TB12 or claim SWAP5 production-solver equivalence.

### Transaction/restart traceability

F-TA04R, admitted through PR #492, recomposes historical PR #172 against current canonical without changing transaction or restart behaviour. It records two complete bounded catalog entries:

- historical A23BL as a real executable regression/contract chain, explicitly not the current mass-completeness oracle;
- pinned F-TB11 transaction/mass/rejected-publication/Restart preservation through its real manifest, validator, replay runner and workflow.

A new documentation static-process check verifies that bounded catalog entries marked `complete` actually provide all required fields and resolve exact repository test/runner locators.

### Blocked production-authority PRs

- **#361** PPA-WU05-B frost: keep blocked.
- **#363** PPA-WU05-D compensated root uptake: refresh later dependencies before any implementation.

### Superseded as live authority

These may still contain useful history, but they are not current control authority:

- **#289** F-ROM0 draft, superseded by canonical F-ROMV2 progression.
- **#366** HYDRO-MEMORY original capability gate, superseded by later canonical ACC/DYN evidence.
- **#378** HYDRO-MEMORY CAP01 blocker, likewise superseded as the live gate by later canonical evidence.

Their owners may close them after confirming that unique evidence is already preserved. Age alone is not a closure rule.

### Owner-controlled research/publication PRs

PRs #359, #365, #371, #389, #181, #199, #217, #218 and #219 stay with their specialized owners and must reconcile to current canonical before any merge with shared consequences.

PR #187 is an immutable blocked PUB-P2E03 experiment and must not be merged as positive evidence.

PR #207 is an immutable blocked first PUB-ME D2 attempt and must be preserved as negative evidence, not converted into a success.

## Current quality-governance authority

GOV-REC01 reconciles the useful governance principles from historical PR #72 against the admitted Status-A and current post-Status-A repository state.

Current governance surfaces:

- `docs/development/quality-governance-a-aa.md`;
- `docs/development/status-a-aa-gap-register.md`;
- `docs/development/lessons-register.md`;
- `docs/verification/theory-code-discrepancy-register.md`;
- `integration/control/STATUS_A_AA_GOVERNANCE_RECONCILIATION_20260920.json`.

The new discrepancy register immediately records the live coupling-authority question as `TCD-SWAP5-001 / INVESTIGATING`. This does not pre-admit PR #486.

## Closed central housekeeping lineage

The former central reconciliation debt is now resolved by current-canonical successors:

- historical PR #72 -> GOV-REC01 / PR #490;
- historical PR #163 -> F-TB13R / PR #491;
- historical PR #172 -> F-TA04R / PR #492.

These historical PRs remain provenance but are no longer open routing items.

## Historical control records

The following records remain valid evidence for their exact earlier snapshot, but are no longer the live project-control authority:

- `integration/f-ci/OPEN_PR_RECONCILIATION_20260919.json`
- `docs/development/open-pr-reconciliation-20260919.md`

Do not rewrite them to look current. Their supersession is explicit here.

## How every active chat should restart

Every specialized chat should begin with the same four operations:

1. read live `integration/f-ci-canonical`;
2. compare it with the last authority explicitly owned by that chat;
3. read `integration/control/SWAP5_WORKSTREAM_REGISTRY.json` for ownership and blocker boundaries;
4. continue autonomously only inside that ownership, returning to central regie for admission, supersession or shared-authority conflict.

### Central regie continuation header

> Continue from live `integration/f-ci-canonical`. Read `integration/control/SWAP5_WORKSTREAM_REGISTRY.json` first. Reconcile only live delta since its snapshot. Own canonical admission, supersession, preservation and cross-workstream conflicts. Do not implement new physics, solver capability, groundwater-coupling methods or production ROM. Process any READY_FOR_REGIE item first; otherwise take the next bounded item from the central reconcile queue.

### Production physics continuation header

> Continue the PPA workstream from live canonical and the PROJECT-CONTROL registry. Own only SWAP4.3.1 production-physics/application-envelope migration. Preserve current admitted owners and fail closed where exact authority is absent. Return a qualified bounded successor to central regie for canonical admission.

### Groundwater coupling continuation header

> Continue F-GC from live canonical and the PROJECT-CONTROL registry. Keep F-GC50 product integration separate from PR #486 coupling-semantics repair. For #486, preserve the distinction between application-level `groundwater_coupled` authority and private Reference `SWBOTB=5` trial realization, finish owner qualification, and return the shared production/coupling/publication admission decision to central regie. Do not invent a local iMOD Coupler product loop or transfer SWAP/FMR state ownership to Python.

### ROM continuation header

> Continue F-ROMV2 from live canonical and the PROJECT-CONTROL registry. No production ROM and no Reference/RossFast mutation. Preserve D28-D31 blockers exactly. Proceed only with evidence that can resolve or narrow the implementation-authority gaps, and return shared canonical implications to central regie.

### HYDRO-MEMORY continuation header

> Continue HYDRO-MEMORY from live canonical and the PROJECT-CONTROL registry. Treat ACC02-F1/F2 and DYN01 as current evidence, but keep Stage 0 unauthorized until the remaining preregistered gates are closed. Research evidence does not widen production ownership by implication.

### Publication continuation header

> Continue the named publication workstream from live canonical and the PROJECT-CONTROL registry. Publications consume canonical science and capability; they do not create production authority. Rebind stale tooling/evidence to current canonical and return only shared preservation/admission changes to central regie.

## Default next action for central regie

The old #72/#163/#172 housekeeping queue is closed. Central regie should not invent a replacement cleanup queue. The next central action is event-driven: a genuinely qualified specialized admission candidate, explicit preservation drift, a deliberate project-control refresh, or a resolved shared-authority conflict. PR #486 remains blocked until its storage/drainage authority is resolved.

This ordering is a routing decision, not a scientific priority ranking.

## MC-IRR01 bounded successor admission (2026-10-11)

PR #1198 is READY_FOR_REGIE and reconciled against canonical `24a69ee415366c4c9d508806bd48bf14c002ea86`. The irrigation owner corrected literal SSDI availability/spatial mapping and added atomic management-to-production Richards execution. Central admission imports that qualified delta without changing shared crop/root, solute, drainage, solver or hydrologic state contracts.

Owner run `38122332488` and F-CI run `38122332557` completed successfully on scientific head `0b421925c28f63bfa3024da303f283e9e9fe35ff`. Production/scientific test blobs are unchanged in preservation successor `2fa04e1f416a3fad5dfb96d90dc4c565778eafbf`; its complete local O0/O2 preservation passed with the irrigation owner gate exercised on every backend route. The only moving canonical delta was unrelated crop preservation/governance metadata.

The physical witness is limited to twelve initial, forcing-consistent 4.8e-8 cm impulses. It does not establish realistic-rate forcing transitions, whole-run restart or general rainfall/evaporation composition. Five #1195 capability admissions remain; eleven full capabilities remain ACTIVE_MIGRATION. The F-KT owner must qualify the event forcing-history interface; MC-CROP01 supplies crop/root lifecycle authority and MC-SOL01 supplies accepted sensor concentration authority. The exact remaining gates are in `integration/audits/MC_IRR01_CLOSURE_PLAN_20261011.json`. Master owner PR #1072 receives a bounded annotation delta with no disposition/count promotion.
