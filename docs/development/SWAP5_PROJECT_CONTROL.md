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
| #1120 | CI/workflow governance | Historical incomplete candidate superseded by the qualified conservative trigger successor below. No remaining dependency-coverage blocker for these two filters. |
| #1083 | PPA-WU03/runon | Closed as superseded by admitted #1086 / `ea4c6548b`; original six-path source/test delta is preserved. F-CI93 derivative debt is separate. |
| #1119 | PPA-WU05B frost | Keep focused finite-guard work under the frost owner; recompose broad whole-source/exact-tree preservation against current canonical. |
| #1103 | HYD/HYST | Finish the active specialized qualification; no central semantics change or admission claim. |
| #1098, #1117 | NUT/SOL | Complete owner-controlled consolidated qualification and source/restart gates; #1117 is not an admission proposal. |
| #1072 | functional-coverage master | Owner reconciles current canonical, including #1198 bounded irrigation annotations; no full-capability promotion from partial physical witnesses. This CI/duplicate closeout changes no capability count. |
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

### Conservative crop trigger and RUNON duplicate closeout 2026-10-11

Reconciliation baseline is canonical `0de42a6abe22e7efbe1be352202ed9637a1dc3b2`, including the later bounded MC-IRR01 #1198 admission. Historical RUNON PR #1083 is closed as superseded by already admitted #1086 / `ea4c6548b7693abbd25d428e85227b43e499a814`. The original six-path implementation/test delta is present in that successor; all five source/test paths are byte-identical there. Later canonical weather guards preserve the runon carrier and assertions. Original head `3ac2ca2b56de887e512412c63faaf5c363688467` and branch remain available. This resolves duplicate queue debt, not the separately confirmed non-M1 derivative defect.

The #1120 trigger successor uses conservative `src/**`, `tests/**` and workflow-self filters on both pull requests and the existing owner-branch pushes. This covers the dynamically resolved CO2 13-path and physical rootgrow 169-path closures, the nine-path root-profile closure, shell component dependencies, stubs and future source/test additions. It excludes documentation/control-only changes. Jobs, numerical commands, options, timeouts, branch selections and dispatch behaviour are unchanged. Exact tested checkpoint `fe697c2161fd42307e892300dc3806c0dba1bfbb` passed path-coverage and positive/negative trigger probes, PR/push parity and job-definition identity; original CO2, depth, profile and physical runtime gates all pass locally at O0/O2. CO2 outputs are byte-identical; the other runners establish separate O0 and O2 passes without an output-identity claim. Exact commands, hashes and unchanged production/test/reference trees are in the existing registry's `continuation_20261011` for #1120.

This is bounded CI trigger qualification and retains baseline scientific/preservation evidence on unchanged dependency trees. It does not close F-CI93, assert global green CI, promote a master capability count or measure queue speed. A `[skip ci]` publication avoids duplicate numerical jobs for the already validated workflow/control-only postimage. The functional-coverage master remains with #1072, and active crop, irrigation, heat, frost, hydraulics and NUT/SOL implementations remain with their owners.

Canonical admission `74a49c15a0e300b3f6a38ca5310889d9a29d2c63`, tree `4fb5651d17b336814e8a8a65b482c6f98629bc75`, was fetched and verified against the local qualified postimage. Production, test and reference trees are unchanged from the named baseline. PR #1120 is closed with recovery comment `6107258525`; #1083 is closed with recovery comment `6107233728`. No new Actions run was observed on the admitted postimage. These are two completed queue dispositions, not two newly implemented physical capabilities.

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

- **#361** is the historical review/source-blocker carrier. The later frost review closeout below resolves that obsolete source claim against exact Git bytes and canonical successors; active frost qualification remains with its existing owner.
- **#363** PPA-WU05-D compensated root uptake: refresh later dependencies before any implementation.

### Superseded as live authority

These may still contain useful history, but they are not current control authority:

- **#289** F-ROM0 draft, superseded by canonical F-ROMV2 progression.
- **#366** HYDRO-MEMORY original capability gate, superseded by later canonical ACC/DYN evidence.
- **#378** HYDRO-MEMORY CAP01 blocker, likewise superseded as the live gate by later canonical evidence.

Their owners may close them after confirming that unique evidence is already preserved. Age alone is not a closure rule.

### Owner-controlled research/publication PRs

PRs #365, #389, #181, #199, #218 and #219 stay with their specialized owners and must reconcile to current canonical before any merge with shared consequences. Later closeouts below record the bounded tooling successors for #359/#371 and historical completed synthesis disposition for #217; release authority remains unresolved independently of those carriers.

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

The later MC-HEAT01 admission receipt below supersedes earlier queue observations of PR #1196; those observations retain their historical meaning.

PR #1198 was admitted as squash `122866c17fbdc62f29bdc7521736bb559a68ee91`; its production and scientific test blobs were verified byte-exact against qualified admission tree `f7669f6228ae8e402ba4f1f7206784d68b3ae201`. Canonical tree `0215eacafd2421cd504a39f514be4ad76d473f43` also retains the concurrent F-CI93 diagnostic metadata commit `64b9fb3d`. It was reconciled against canonical `24a69ee415366c4c9d508806bd48bf14c002ea86`. The irrigation owner corrected literal SSDI availability/spatial mapping and added atomic management-to-production Richards execution. Central admission imports that qualified delta without changing shared crop/root, solute, drainage, solver or hydrologic state contracts.

Owner run `38122332488` and F-CI run `38122332557` completed successfully on scientific head `0b421925c28f63bfa3024da303f283e9e9fe35ff`. Production/scientific test blobs are unchanged in preservation successor `2fa04e1f416a3fad5dfb96d90dc4c565778eafbf`; its complete local O0/O2 preservation passed with the irrigation owner gate exercised on every backend route. The only moving canonical delta was unrelated crop preservation/governance metadata.

The physical witness is limited to twelve initial, forcing-consistent 4.8e-8 cm impulses. It does not establish realistic-rate forcing transitions, whole-run restart or general rainfall/evaporation composition. Five #1195 capability admissions remain; eleven full capabilities remain ACTIVE_MIGRATION. The F-KT owner must qualify the event forcing-history interface; MC-CROP01 supplies crop/root lifecycle authority and MC-SOL01 supplies accepted sensor concentration authority. The exact remaining gates are in `integration/audits/MC_IRR01_CLOSURE_PLAN_20261011.json`. Master owner PR #1072 receives a bounded annotation delta with no disposition/count promotion.

## ROM and HYDRO-MEMORY terminal-carrier reconciliation (2026-10-11)

Reconciled at canonical `9d95eacb6619f7fece1d3bfe7b3e068304836ecd`. Layer-ROM #495 explicitly closes its core feasibility phase; #496 closes APP0 at an application-authority blocker; #576 explicitly closes ROM-ACCEPT01 with no current Layer-ROM acceptance run authorized. These are completed research/authority carriers, not production ROM admission. Selecting L4/L6/R8 still requires independent purpose criteria.

ROM remaining requirements stay with the independent purpose/application authority: GW-R needs a recharge/bias/temporal envelope or governed response mapping; GW-D needs complete original or newly governed validation-population authority and a separate component structural-error allocation where applicable; SCI-P needs depth-resolved absolute/profile/timing fidelity authority. The qualified public LHM archive is not the withheld original population. Formal application endpoints, numerical solver budgets and reduced-model acceptance remain different authorities. No candidate response was generated or viewed in this closeout.

HYDRO-MEMORY #366/#378 are already explicitly classified above as superseded live gates by later canonical ROOT-HYD01/ACC/DYN evidence. Preserve the original negative net-root-extraction diagnostic, but route current bounded root-active research capability to ACC02-F1/F2 and DYN01/DYN02. Stage0 remains unauthorized and the production/coupling owner envelopes are not broadened.

Full unique research history is preserved without wholesale merging: original heads are frozen under `recovery/regie-pr495-20261011-07c89de1`, `recovery/regie-pr496-20261011-76daff05`, `recovery/regie-pr576-20261011-41799780`, `recovery/regie-pr366-20261011-e79d8901` and `recovery/regie-pr378-20261011-979113fb`. Each remote ref was fetched and exact head/tree verified before closure. The existing registry records complete SHAs, trees, terminal authority paths, limits and reopen requirements. Keep these recovery refs fixed; original branches also remain retained.

All five carriers #495/#496/#576/#366/#378 are now closed after fetched canonical recovery checkpoint `2fb38420c24ee82c7d0df2582345d99a6ed912fe` was tree-verified. Recovery comment IDs are `6108085622` / `6108085864` / `6108086117` / `6108086392` / `6108086621`. No new Actions were created by the recovery refs; all pre-existing runs on those exact historical heads are terminal.

Keep #528 analytical coupling research and #540/#559/#581 Ribasim qualification carriers owner-controlled. Their original records do not establish the missing final qualification. Expected scientific sign/storage or12h transfer discrepancies must not be bypassed, and product BMI clock qualification does not constitute SWAP production admission.

This round changes only the two existing metadata authorities. Scientific dependency trees remain unchanged; zero capability promotions, new Actions, candidate simulations or external acquisitions are required.

## Solver/macropore historical-carrier closeout (2026-10-11)

Reconciled at canonical `10b94cbdcd902889c71444d611c68c0460a17cae`. The A8, PERCH and A26 old carriers are superseded by explicit owner canonical closeouts, not new implementations:

| Historical PR | Selected authority | Bounded disposition |
|---|---|---|
| #924 A8 | #923 / `9bad713b0`, `PPA_WU05A8_CLOSEOUT.md` | Standard single-column Reference FMR admitted; alternative source/dynamic-crack files are preserved, not declared admitted. |
| #961 PERCH20 | #963/#964 PERCH21, `PPA_WU05_PERCH21_RESULT.md` | Perched/current-iterate/retry/restart successor admitted, owner and postmerge preservation complete. |
| #968 A26 reconciliation | #969 / `695b1b382`, `PPA_WU05A26_CLOSEOUT.md` | Bounded accepted-state-frozen first-order live RFM admitted; shared backend has identical 28,779 Fortran tokens to admission despite formatting differences. |
| #743 TIMEINT12 | Original explicit negative closeout and canonical `F-PE-TIMEINT12_CLOSEOUT.md` | Fully implicit dynamic-top route not qualified; only six of twelve physical cases complete. No dynamic-top BDF2 production claim. |
| #762 initial TIMEINT17 | Canonical requalification closeout and 2026-09-29 handoff | Initial carrier superseded by 96/96 same-route research qualification; general release/desaturation and production event semantics remain open. |

The full 74-file deltas of these exact original heads are preserved in `integration/audits/evidence/SOLVER_MACROPORE_REGIE_CLOSEOUT_20261011.tar.gz.b64`; decoded SHA256 `d320dfd295986ddad001cf8168bf99563b33266510f6fff15d1a018be62edd14`. Every extracted member matches the original Git blob and SHA256. Original branches remain retained. No older source/state/backend or archived workflow is replayed over current MIGMAC, thermal, crop or irrigation ownership. Historical scientific evidence remains bound to its original scope and run, not represented as a fresh benchmark.

All five historical PRs are now closed after evidence checkpoint `317682c55fa01fd247d4db584ac24a648a6c513b` was fetched and its tree verified. Recovery comments for #743/#762/#924/#961/#968 are `6107973257` / `6107973568` / `6107973899` / `6107974180` / `6107974501`.

PR #740 retains 119 unique source/calibration/research files and needs an ELASTIC-owner census; later mineral ELAS admissions do not by themselves supersede every result. PR #987 remains branch-only A28 approximation work under its RFM owner, with Q4 long-history/replay/rollback qualification pending and fixed64 as default. Neither is admitted or closed by this batch.

This delta is metadata/evidence only: scientific source, tests, reference, tools and workflows are unchanged. No numerical rerun, Actions or new capability-count promotion is justified. Existing shared-authority blockers remain open.

## Frozen and completed research-carrier closeout (2026-10-11)

Reconciled at canonical `3d326d8fef3529d7a65737d9e4af0c86a41f06f8`. Four original owner records already establish a completed or inactive bounded work unit, without production admission:

| PR | Owner disposition | Remaining requirement / owner |
|---|---|---|
| #670 MULTI05 | `CLOSED_HOST_CAPACITY_BLOCKED` | Trusted-host operator supplies a real high-core host before frozen scaling research can reopen. Production default1/admitted2/4 stays unchanged; oversubscription is not real-core evidence. |
| #897 ELASTIC57B | Completed qualified research-controller question | ELASTIC owner separately establishes a physical temporal budget and production transaction policy. The finite nine-step/eight-retry result is not production acceptance. |
| #912 ELASTIC72A | Qualified negative source-feasibility result | Direct BHR-GT peat calibration route is closed; five high-organic intervals remain descriptive. Successor #915 is frozen, not active missing production. |
| #915 ELASTIC72B | `FROZEN_NOT_ACTIVE` | No active action/blocker. Reopen only under the explicit owner sensitivity/data/mass-error/new-evidence criteria, not because more time or runner capacity becomes available. |

The complete 90-file original deltas, including the cumulative ELASTIC46-57B lineage, are preserved in `integration/audits/evidence/FROZEN_RESEARCH_REGIE_CLOSEOUT_20261011.tar.gz.b64`; decoded SHA256 `8df53b50c76c00f9a988138e680e93f989f0a339091616f9c80b2034c567cd89`. Every extracted member matches its original Git blob and SHA256. Original branches remain intact. Archival workflow/source files are evidence only and are not added to executable canonical paths. Exact heads, gates, claim boundaries and reopen conditions remain in the existing workstream registry.

All four PRs are now closed after fetched canonical evidence checkpoint `226fd8d09f533645dce086010120dc500f88a625` was tree-verified. Recovery comments for #670/#897/#912/#915 are `6107903063` / `6107903517` / `6107903903` / `6107904251`. These closures preserve owner re-entry conditions; they are neither a merge nor new production qualification.

TOP02 #953 remains a qualified component waiting for TOP03 transaction and exactly-once mass publication. TOP03 #956 remains unique owner-controlled contact/surface/numerical research, not production admission: accepted-window, external storage ownership, rollback/Restart v1, transient acceptance, calibration and complete preservation remain open. Research Jacobian/discriminator artifacts cannot be imported as production repairs. #1001 and #1005 remain unique research without explicit final owner closeout.

This is metadata/evidence-only reconciliation with zero capability admissions and zero new Actions. Scientific dependency trees equal the previously qualified canonical postimage; repeating numerical gates would add no new evidence. Inactive peat research is not an active scientific blocker.

## PERF02 and completed E2E research-carrier reconciliation (2026-10-11)

Reconciled at canonical `669a75ff996938fd0538c715ec43fe93d06b74de`: PR #986 is superseded by admitted #998 / `c618cef80e53c3b1a670a76ebb0470aa837a37e1`. Both production blobs, all eight PERF02 performance tests/runners and the frozen derivation/preregistration equal current canonical. The interim result survives verbatim with final qualification added; the active-chain runner only renames the compiled gate object. Historical workflow definitions are evidence, not missing production semantics.

PR #1003 has an explicit `NEGATIVE CHARACTERIZATION, CLOSED` owner closeout; its short trajectory is unsuitable for physical PERF02 frequency estimation. PR #1007 has a final `RESEARCH_CLOSEOUT_DECISION_B`: eligibility is a limited low-demand/dry-state niche, with no broad production-speed or seasonal-frequency claim. Its frozen holdout and invalid intermediate fixture findings remain evidence. These two completed research carriers can close without merging their research code. PR #1008 remains the owner-controlled PERF03 attribution successor.

All 26 changed files of the exact three original heads are preserved in `integration/audits/evidence/PERF02_E2E_REGIE_CLOSEOUT_20261011.tar.gz.b64`; decoded SHA256 `1d69faf79329e8ca2cc389cf1a397c36481360dd478991c8e774ba42d0306ebe`. Archive members were decoded and byte-checked before closure; original branches remain intact. Detailed heads, classifications and next owner actions are in the existing workstream registry.

Keep #1001 (unique measurement), #1005 (unique sequential host) and #1008 (active attribution) open under the performance owner. #1009 is a unique restricted SWINTER1 composition candidate, not superseded by SWINTER2/detailed-met admissions. Its simulated FMR result test does not establish physical execution; all ten frozen gates and current crop/runtime overlap must be adjudicated by PPA-WU04-C/MC-CROP01. #700 remains a historical 862-file nonadmission synchronization carrier requiring a PPA-owner census before any supersession. No wholesale production replay is safe.

The three carriers #986, #1003 and #1007 are now closed after canonical evidence checkpoint `73fa4fabb562946942c431f948b2082f65ef1ca6` was fetched and its tree verified. Recovery comments are respectively `6107779714`, `6107779932` and `6107780208`.

This round changes metadata and an evidence archive only. Production, scientific tests, references, tools and workflows equal the existing qualified canonical dependency surface; no numerical reruns, Actions or new capability-count promotions are justified. The owner-controlled and shared-authority blockers listed above remain open.

## MC-HEAT01 canonical admission (2026-10-11)

Canonical `e326931dbc3a518ec93574ba6cdf3024628eaddc` admits `SW431-TEMP-ANALYTIC`, `SW431-TEMP-BC3`, `SW431-TEMP-BC4` and `SW431-TEMP-BOTTOM2`. PR #1196 is closed/merged; its original owner head `decd2e67b8a182f1448a173b18bbc232749dd5b5` and initial merge `30246dc50` remain ancestors. All three production blobs equal the qualified owner blobs exactly. Central work adds bounded preservation recognition and admission evidence, with no new production physics. The concurrent irrigation source, sensor/event gates and audit receipts are retained.

Complete local moving F-CI passes on published exact head `f177b589516e7c775bf884b6f2e39e154f5e0fba`. The admitted source tree is `6c6534eabc150455eec2c184020c658b091c794e`; source, tests, reference, tools and workflows equal that tested head. Original thermal process/runtime O0/O2 and repeat identity, legacy default F-VQ58 oracle, F-KT22 serialized trajectory and bounded frost runtime pass. Unknown thermal/backend postimages fail closed before compilation. All fourteen immutable F-CI refs and the complete workflow remain unchanged and inherit terminal green run `38121781430`; zero new Actions or dispatches were needed. Skip-ci metadata publication does not waive a scientific check. Documentation source checks and JSON validation pass; strict MkDocs is unavailable locally.

Full qualification logs are durable in `integration/audits/evidence/MC_HEAT01_REGIE_QUALIFICATION_20261011.tar.gz.b64` (decoded archive SHA256 `b9f04a141cbc2bae855f0b73dd7e4110c5786117a4ea7978a00ffc0d086232c6`). Exact output hashes, source authority, owner checks, negative guards and paired EB-I25 logs are in existing `integration/audits/MC_HEAT01_STATUS.json`.

`SW431-TEMP-SNOW` remains withheld: combined optional-state layout and one-day Snow versus accepted-substep thermal event timing need existing shared-authority admission. No Frost-SNOW promotion follows. EB-I25 independently fails the same external full-half outflow fixture at O0 on canonical `3cc40d599` and candidate `f177b589`; its cause remains INVESTIGATING under the F-KT22/EB-I25 energy-ledger owner, with O2 unexecuted. The separate HeadCalc/dynamic-top F-CI93 implementation defect remains open. Master coverage stays with PR #1072: reconcile only these four admitted dispositions, retaining all other blockers and owner-controlled workstreams. No global coverage count is asserted.

## MC-IRR01 stable-storage central admission (2026-10-11)

PR #1200 is admitted at `ea4759a0633011f26e8ee43126db2484c0def8b3`: exact existing constitutive storage-increment invocation for all explicit providers, with unchanged formulas, fallback, mass/temporal thresholds, history and state ownership. Owner `38132433330` and all frozen/moving F-CI in `38132433375` pass; all eleven postimage paths are verified. A feasible 1-cm retained-history event at 48 cm/day and twelve root/depth routes are qualified. The former 3-cm negative fixture cannot establish a solver defect and is retained with corrected interpretation. Five fullcap admissions and eleven ACTIVE_MIGRATION rows remain; common root salt binding, real-depth source-off/spatial restart and accepted crop/root/solute/allocation lifecycle are separate gates.

## Historical E2E carrier and owner-evidence reconciliation (2026-10-11)

Reconciled from canonical `87a9516e43562e241ea0511b56da9be1c257c116`, preserving the later #1200 stable-storage admission. The existing registry field `owner_research_reconciliation_20261011` records bounded results, original and tested heads, exact fixture blobs, recovery refs and remaining owner gates.

PR #1001 is a completed historical E2E02 ON/OFF measurement and initial eligibility diagnostic. Owner run `37112457801`, job `111172863478`, succeeded on actual PR merge checkout `33cc1fdfc00d61ad51879c272908cebc2ad50d31`; both unique fixture/runner blobs equal original head `162dd96e95d138b2750888fbbb79b411d0dee007`. Later E2E05 Decision B corrects physical oxygen construction and both demand carriers; PERF03 #1008 explicitly consumes the E2E02 timing finding and owns the next attribution. Earlier matrix observations must not override that corrected frontier. No growing-season frequency or broad performance claim follows.

PR #1005 is a completed historical constant-host characterization. Owner run `37124112956`, job `111205856925`, succeeded on actual merge checkout `e2ce38129d75c9cfd15fe41ecadf0db4a8ce9ec2`; both unique blobs equal original head `6e0b78a8876c3878cf7daddc477a0daec000ba1e`. The final O2 fixture reports120 accepted daily states, zero PERF02 hits, constant h1=-10 and zero net/storage change. Its reported A2 timing is not a PERF02 speedup and not a dynamic seasonal workload. Corrected nonstationary screening/holdout is retained in E2E05; PERF03 remains active.

The original O3 measurement and O2 host runs are historical research evidence, not new O0/O2 production qualification. Original adjacent F-CI runs `37112457758` and `37124113078` failed and remain negative evidence. Closing these research carriers does not merge their implementation or rebind that evidence to current canonical. Complete original heads and actual tested merge postimages are frozen under `recovery/regie-pr1001-20261011-162dd96e`, `recovery/regie-pr1001-tested-20261011-33cc1fdf`, `recovery/regie-pr1005-20261011-6e0b78a8` and `recovery/regie-pr1005-tested-20261011-e2ce3812`; all refs were fetched and identities verified. Scientific result lines are retained in the existing registry before closure. Keep these recovery refs fixed.

PR #740 remains unique research:119 changed paths,116 absent at canonical and3 different, with no production source changes. Its frozen M5 inverse-stress/20-kPa wet-state transfer is distinct from the later mineral M1/h=-100 policy. Terminal run `36540669506`, job `109315024319`, qualifies21 intervals with16 supported and5 extrapolative; it does not authorize field-scale ELAS, peat assignment or a universal default. The ELASTIC physical/source authority must adjudicate this unique lineage before supersession or any new production-shaped transfer.

PR #700 remains an unqualified historical synchronization carrier:862 changed paths,773 absent and89 different at canonical, including150 absent and10 diverged source paths. Path absence is not physical-capability absence because current owners use later replacements. Its explicit WU04C retry/noncommit blocker and shared HeadCalc/backend/bootstrap/irrigation/restart/solver divergence prohibit a wholesale replay. PPA with the crop, irrigation, solute and macropore/runtime owners must map unique candidates to current capability/successor authority before selective recovery or closure.

Coverage reconciliation remains with active owner #1072 at `f2cfaa1c8d46e7025d7d46a891b92288d5b94e55`: the four admitted thermal rows still say ACTIVE_MIGRATION despite admission `e326931` and handoff `6107527878`. The owner must reconcile those four dispositions, keep TEMP-SNOW/Frost-SNOW open, and update the later #1200 bounded irrigation annotation without promoting any of the eleven active fullcaps. The master ledger is branch-only; central regie does not import or overwrite it. No global counts or completed master qualification are asserted.

This round changes only the two existing metadata authorities. Production, scientific tests, reference, tools, workflows and assets retain the named canonical baseline. No numerical requalification or new capability admission is justified by research-carrier disposition. Canonical metadata publications use `[skip ci]` and start no Actions; no manual Actions were dispatched.

Closure receipt: #1001 and #1005 are closed, not merged, with recovery comments `6108331856` and `6108332130`. Evidence was canonical before closure at `a22e5b924f54e2010d862ef962c7cbb957097196`, tree `39762dcb48eb1b96e682e28d07bd7d29348c6f13`. Open #740 and #700 have explicit owner classifications in comments `6108338364` and `6108338461`; #1072 has the exact pending four-row/later-irrigation handoff in comment `6108338589`. JSON, documentation source, strict MkDocs and whitespace checks pass. Fixed recovery refs retain both original heads and actual tested merge checkouts; these dispositions add zero production capabilities.

Actions accounting correction after final live verification: creation of the four fixed recovery refs triggered the historical broad A26 push workflow. Runs `38133822089`, `38133822470`, `38133823582` and `38133823679` are all COMPLETED/SUCCESS; exact jobs/refs are recorded in the existing registry. No run remains queued/running. These automatic A26 replays do not establish E2E production admission. Account for historical broad push triggers before further recovery-ref creation; no repeated numerical run or workflow change is made in this closeout.

## Publication evidence and export closeout (2026-10-11)

Reconciled from canonical `a787f6340328a06885a145f6d88a52d921a458e7`, retaining #1200 stable-storage admission. The existing registry field `publication_regie_closeout_20261011` records exact original heads, historical terminal checks, current dependency drift, qualification and closure recovery. No new global ledger or production capability count is created.

Original postimages for #187 (eight files), #207 (five) and #217 (four) are durable before closure at canonical evidence checkpoint `d620326cd0adfe7e2d1e27ca55704a83b230663e`. Archive `integration/audits/evidence/PUBLICATION_REGIE_CLOSEOUT_20261011.tar.gz.b64` decodes to SHA256 `5d0670fd44a9fc71f2893928c1f12a921e050733b337939f8e382f278d7708ff`; its manifest binds exact original Git blobs and modes. These original branches remain intact.

- #187 is a completed immutable blocked calibration experiment: 47/162 valid and 115 invalid at the initial O0 matrix, with no threshold freeze or RossFast execution. Later P2E04 balance adjudication and P2E09 threshold freeze are separate authorities. Its failed calibration remains negative.
- #207 is a completed immutable blocked first D2 attempt. Neither CLEAN nor MUTANT executed after compilation failure; no detection or production-defect verdict follows. Later canonical D2 success is a separate experiment.
- #217 is a completed historical cross-defect adjudication, `GO_NARROWED_CLAIM__NOT_MANUSCRIPT_READY`. D1/D3 structural prevention and D2/D4/D5/D6 earlier detection do not establish unique/higher ultimate detection, whole-model equivalence, statistical independence or current dependency qualification. Preserve G1 complete file-driven E2E, G2 checkpoint/run/restore/rerun, G3 warm-start invariance, G4 additional hydrologic replication and G5 literature closure as PUB-ME programme gates.

### Bounded export-tooling qualification

The two-path #359 successor recomposes its original export guards on current canonical, with a proportional presentation margin of 10% instead of 1.5%. Original owner run `35426072539`, job `105852120580`, failed because F5 touched the right page edge; that exact diagnostic was reproduced locally. All seven governed SVGs remain byte-identical to both current canonical and the original owner head. Plot coordinates, text and scientific claims are unchanged. Both independent exports pass embedded fonts, one-page/aspect geometry, strict nonblank/no-page-edge Poppler rendering, per-figure size and flat ZIP/total-size gates; the F5 title, panels, axes, legend and limitation note were visually inspected.

PDF and ZIP bytes differed between the two independent exports: repeatability remains **NOT_PROVEN** despite SOURCE_DATE_EPOCH and fixed ZIP metadata. No byte-identity promise is made. The workflow retains that explicit classification. Local qualification uses the workflow's exact CairoSVG 2.8.2, Pillow 12.3.0 and pypdf 6.1.1. Complete manifests, original failure, second-export log and original/qualified tooling postimages are preserved in `integration/audits/evidence/PUBLICATION_EXPORT_REGIE_QUALIFICATION_20261011.tar.gz.b64`, decoded SHA256 `52f9757f2922c8e49771cb50b3fac855c95280f7cae8d7a4cf772e7fd494d806`.

This qualifies presentation tooling only. Concurrent #1201 was already admitted by its owner at `73796d85ba8de962673390a40d1be54e9c152d53`; that live base is retained in full. Its source/tests trees equal qualified owner `70eedcd157d1f0874823f350293a145ca26ae4c2`, and all qualification-archive log hashes were verified, including terminal full moving F-CI PASS. Root scalar salt, realistic sensor half-event restart and source-off remain bounded owner admissions; accepted solute concentration binding is separate and no fullcap promotion follows. The export's SVG/plan dependencies are unchanged by #1201. Production, scientific tests and reference equal this live canonical base, so their existing O0/O2 and F-CI evidence is inherited without another numerical run. No submission, archive release, production capability or scientific manuscript admission follows from the export. #486 storage partition/exclusive drainage and #371 finalization holds remain authoritative.

### Remaining publication owners and decisive blockers

| PR | Owner | Remaining gate |
| --- | --- | --- |
| #181, #199 | PUB-GC contract / PUB-ME literature programme | Consolidate unique contract/preregistration material and complete dated backward/forward literature closure. #199 depends on #181. |
| #218 | PUB-ME D6 / F-CI98 preservation | Closed by current bounded regie replay at `e2743c8b5e353c93453e1134e9f4d7884cf79dab`; O0/O2 exact historical SHA retained. Historical failed F-CI stays negative. |
| #219 | PUB-ME physical replication / Reference execution | Closed by current bounded reverse-D2 replay at `e2743c8b5e353c93453e1134e9f4d7884cf79dab`; O0/O2/classification pass unchanged historical tolerances. Its G1 remains distinct from #217 G1 complete file-driven E2E. |
| #365 | DIF-P0 research | H3 requires a second independent iterative Richards method. RossFast cannot be relabelled as such; P0A authority binding does not close Phase0. |
| #371, #486 | PUB-GC finalization / central F-GC admission | Release, license/archive PID and author metadata remain unresolved. CSR-B1-STORAGE-PARTITION and CSR-B2-DRAINAGE-OWNERSHIP hold submission; no Hupsel rerun authorized. |
| #389 | PUB-Stromingen editorial | Internal review only; refresh public NHI terms/status and resolve owner editorial/authorship choices before external publication. |
| #587 | PUB-GC scientific/editorial handoff | Consolidate unique fixed-interface theory/manual draft with #486 authority. Handoff does not establish new production or novelty evidence. |

The bounded export successor is canonically admitted at `38129aba14e44b70bb436feee46c10922cb5ea56`, tree `7ea8e9f6f99df582093eeb73ee64372bb6aa6596`, under a safe lease from owner receipt `d8414c1ba11bee9f061622fd2495f631a57d2383`. The fetched full tree equals the local postimage; production/tests/reference equal that live base exactly. Both evidence archives decode to their recorded hashes and all17 historical postimages match their original Git blobs. The concurrent #1201 receipt is preserved.

PRs #187, #207, #217 and #359 are CLOSED/UNMERGED with original heads unchanged and branches retained. Closure comments are `6108514300`, `6108514640`, `6108514976` and `6108515347`. The three completed historical units add zero production capabilities; #359 is closed as superseded by the selective tooling successor. Open #181/#199/#218/#219/#365/#371/#389/#587 have explicit owner/blocker comments recorded in the registry. Master #1072 received comment `6108519849` for the bounded #1201 irrigation annotation and pending four thermal dispositions; no global count or fullcap promotion is inferred. Existing specialized implementation remains untouched.

JSON, whitespace, documentation source and strict MkDocs pass. There are zero new Actions, dispatches or recovery refs in this publication batch. Original historical failed checks remain negative; no scientific guard or publication hold was relaxed. Current scope and exact recovery remain in the two existing control authorities.

## MC-IRR01 root salt and realistic event admission (2026-10-11)

PR #1201 is admitted at `73796d85ba8de962673390a40d1be54e9c152d53`. Root TCS2/3/4/6 share the historical TASK3 salt modifier with sensor scheduling, preserving DCSLIM-before-salt-before-TASK4 order. Literal 48 cases, realistic root and sensor physical/event restart, source-off and complete local F-CI preservation passed O0/O2 on persisted `70eedcd157d1f0874823f350293a145ca26ae4c2`. Admission preserves all scientific dependency subtrees exactly. All 15 canonical paths verified; immutable full logs are versioned. No numerical thresholds, solute owner or crop/root state changed; no full-capability promotion.

The previous broad MC-SOL01 blocker is corrected: PR #1015 already admits matrix mobile salt. Its same-state CML needs an irrigation-owned read-only adapter and forwarding of the existing salt temporal policy. That successor remains separately unadmitted. Whole-run crop/root/weather and persistent external allocation remain separate authority gates.

## F-CI93 non-M1 fixed-conductivity repair qualification (2026-10-11)

Under explicit user delegation of the central shared decisions, the existing Task2 adapter now resolves the actual trial-start top-node conductivity from the existing constitutive owner and supplies the existing fixed-K dynamic-top derivative contract for the already admitted SWKIMPL=0 non-M1 route. M1 binding/eligibility/legacy compatibility remain byte-unchanged; no HeadCalc, provider formula, state/restart owner or threshold changes are made. The stale-global-k first variant failed the unchanged atmospheric oracle and is retained as negative evidence.

Local native immutable FKT15 Task2/surface/SWBOTB=2 and FSI35 dispatch O0/O2 pass, including hard mass, retry and worker identity. M1 owner and independent fixed-carrier/default/KSATEXM and headed finite-difference assertions pass. Full moving central preservation exited0 with216 distinct PASS markers. Concurrent PR1201 source changes were retained: all27 FCI93 native compile dependencies are unchanged, while the complete current irrigation owner surface was freshly requalified at O0/O2, including literal48/root12 salt cases and exact admitted physical hashes. The dependency-specific guard avoids freezing unrelated source owners.

Exact authority and raw logs are in `integration/f-ci/F-CI93_STATUS.json#non_m1_fixed_k_repair_20261011`, `integration/audits/FCI93_NON_M1_FIXED_K_DECISION_20261011.json` and the recorded qualification archive. Fourteen unchanged historical/frozen F-CI checkouts retain terminal green38132433375; actual moving and owner science is local successor evidence. No new Actions or manual dispatches are needed for these already executed gates. PR #1202 canonically admitted this bounded repair at `d8b2640890203c3444f3d65b8918e31b52cdf74f`, head `c3ec083300780cfce027448059ba0cc8b5e651b4`. Canonical production blob and all27 compile dependencies are verified. Concurrent admitted PR #1203 adds an independent salt binding outside that closure; its source and preservation calls are retained. MC-CROP01 and fullcap/master closure remain open.

## Mechanical finalization and historical frost review closeout (2026-10-11)

Reconciled from canonical `0379282491bdc6b7de5ffb8efd0334967eeae880`. Existing registry field `finalization_frost_regie_closeout_20261011` binds the exact original heads, terminal historical checks, source census, bounded tooling qualification and closure recovery. No new global status authority is created.

The old #361 claim that frost source bytes cannot be materialized is superseded. Git archive `integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64` contains complete `SWAP/frozencond.f90` (7810 bytes, SHA256 `edd16b08ff238ee41d264d1c4870726f1232fb1143c1340f2dc21f94a3b909cf`) and `SWAP/temperature.f90` (32708 bytes, SHA256 `92c39d296f41a60cfe3b66f8d1886ea938a53b4e0ea49e7ae1a23dd9680bd338`). Both match the original #361 authority exactly. Current `PPA_WU05B_STATUS.json`, source manifest and canonical closeout establish the later bounded hydraulic admission #1018; B19 has separate runtime admission #1078. The historical review carrier is superseded, without new frost implementation or numerical admission. Aggregate frost remains incomplete; #1119 and later owner-specific composition/research boundaries remain untouched.

The #371 successor imports only four mechanical paths: finalizer, its workflow, unresolved input and contract. Seven other historical package/checker/doc deltas are archived rather than replayed. All24 current publication-critical blobs match the incumbent prearchive inventory. Canonical input remains null/false; no release ID, licence, archive PID, author declaration or scientific result is invented.

The original finalizer lacked the later #486 scientific-release hold and accepted placeholder licence text despite its own contract. The bounded successor rejects placeholder authority values and rejects archive-ready, submission-ready and binding emission while `CSR-B1-STORAGE-PARTITION` and `CSR-B2-DRAINAGE-OWNERSHIP` remain. Only a separately qualified central-authority successor can reconcile that guard. Authority-ready checks governance input alone and cannot authorize scientific release.

Fourteen local mechanical qualification cases pass on persisted `3e8350d341da82340ff4111668b3c1f8752681db`, including default pre-authority success, missing authority, predecessor reuse, placeholder licence, mismatched commit, asset drift, E7 zero-window drift, accidental external zip and refusal to archive/submit/emit even with complete synthetic metadata. Synthetic values are test fixtures, not repository authority. Zero binding manifests were emitted. Production/tests/reference remain exactly the canonical base, so current numerical O0/O2 and F-CI preservation are inherited without rerunning physics.

Complete original #361 (six files) and #371 (eleven files) postimages, four qualified tooling paths, harness and full14-case outputs are preserved in `integration/audits/evidence/FINALIZATION_FROST_REGIE_CLOSEOUT_20261011.tar.gz.b64`, decoded SHA256 `52d8c4cb19d2a4a257109131ef69e4faece55e15f2521e5fa7b110f1a3c8992c`. Historical owner/finalizer checks passed, but both original final-head F-CI checks failed and remain negative; this closeout makes no old-head preservation claim.

Remaining release blockers belong to central F-GC #486 (physical storage partition and exclusive drainage) and PUB-GC governance/archive/editorial owners (R1, L1, A3, author declarations and42 placeholders). No Hupsel rerun, archive creation or external submission is authorized. Master coverage gets no production-capability promotion.

The four-path mechanical successor and complete evidence archive are canonical at `cdd9d0cbc00e63b03a3d79f941d57aea529d102b`, tree `44d409e98b9640847a5efb92f4df2421d2e82820`. Fetched full-tree identity, qualified tooling blobs and unchanged production/tests/reference were verified; canonical pre-authority validation also passes with the scientific hold printed explicitly. PR #361 and #371 are CLOSED/UNMERGED with original heads unchanged and branches retained, comments `6108624806` and `6108625162`. All17 original postimages and all archive members were byte/hash verified before closure. JSON, documentation source, strict MkDocs and whitespace pass. Zero new Actions, dispatches or recovery refs; no old failed F-CI result was relabelled and no scientific threshold was weakened.

## MC-IRR01 accepted salt runtime admission (2026-10-11)

PR #1203 is admitted at `664a89b1a0e47b4c2ad2324f614d7d51c67bb90e`; all 11 owned postimages verified. Irrigation derives concentration from the same accepted PR1015 matrix salt mass and water state, forwards the existing salt temporal policy, and retains event depth/rate/end through physical salt/water restart. Sensor12/root24 and negative layout/time/geometry proofs pass O0/O2; full local lineage-aware F-CI passes on persisted `3b9223720e4fea58ba4256c10be2faaf686011c8`. Immutable full logs are versioned. No new salt transport physics or shared state layout is introduced, and no full-capability promotion follows.

The precise remaining shared application hook and live crop #1197 overlap are recorded in `integration/control/MC_IRR01_APPLICATION_COMPOSITION_20261011.json`. Existing public serialized physical bindings are qualified; they do not establish authentic weather/evolving crop/root composition through private bootstrap columns. The independent external allocation receipt successor remains in full local qualification.

## Central concurrent-admission reconciliation (2026-10-11)

Reconciled canonical `73da18b9395c112a3a4eaa81c9e3fba4414ec8e8` after the owners admitted #1202 and #1203. The exact original heads/merges, archive hashes, dependency method, coverage handoff and preserved closeout receipts are recorded under existing registry `finalization_frost_regie_closeout_20261011.concurrent_admissions_reconciled`. No duplicate merge or production implementation was performed by this closeout.

The central F-CI93 non-M1 headed-interface blocker is closed by qualified #1202 under its existing central authority. All27 native compile dependency blobs match current canonical. The accepted-salt sensor/root/guard fixtures each resolve176 paths using the same module population as their runners; all production dependencies match qualified #1203 and exclude the changed Task2 adapter. Manual legacy HeadCalc, explicit stubs and all six test/runner blobs also match. Both qualification archives and all recorded logs were hash-verified, including terminal full local lineage-aware F-CI and owner/independent O0/O2. Their preserved dependency surfaces justify inheritance without duplicate numerical runs. Historical negative variants remain negative.

All four admitted mechanical finalizer paths and its complete historical evidence archive remain exact at this combined canonical head; #361/#371 closure receipts are retained. Release/submission holds remain with central F-GC #486 and PUB-GC governance/archive/editorial owners. Crop #1197, shared bootstrap/dispatcher application composition and independent external allocation remain with their existing owners; the precise shared hook gates are in `integration/control/MC_IRR01_APPLICATION_COMPOSITION_20261011.json`. There is no irrigation/crop fullcap promotion.

Master #1072 at `5680665f7a6b8f73af01c97102a880bc02ea94f5` retains #1200/#1201 bounded annotations but still classifies the four admitted thermal capabilities as ACTIVE_MIGRATION with obsolete implementation-absence claims. Owner handoff comment `6108731792` binds those four existing admissions and the new bounded annotations; no active master files or global counts are overwritten. Fresh queue:26 open PRs, including integration PR #58; all remaining25 owner candidates retain the existing exact blocker classifications. Zero new Actions, dispatches or recovery refs. The lone queued historical A26 run37642390231 is unrelated to these admissions; no necessary active run remains.

## PUB-ME D6 / reverse-flow D2 current qualification (2026-10-11)

Reconciled #218 (`8c96b3360593978b99b31430cef9d1c4c31de061`) and #219 (`fa9cc6c456cd7c4dc65709818841fc716de93c03`) from canonical `31b0db16ce2f9463e316495e92e3b02faf8d4d8d`. Existing registry `publication_regie_closeout_20261011.d6_g1_current_requalification` is the bounded admission/recovery record. Only nine unique publication design/result/test/build paths are selected. Both original automation definitions are archived; no existing canonical preservation workflow is altered. Original historical designs/results are retained with dated successor annotations.

Science executed on persisted `240961d6e6debd1e71230ffa5e5602268bc0651a`. Both original fixtures, fault operators, B1/B2 comparators, historical budgets/tolerances and classification rules are unchanged. D6 passes O0/O2 with exact historical output SHA `9563ed157258f1993a826a9ef498498cafa45254266818d877db73bb28c88643`, retaining EARLIER_DETECTION. Reversed-flow D2 passes O0/O2 with output SHA `41cde3050cfac802ce9cade44ec20bb482295f5c85b1dd0bdeea29b02eea1875`, retaining REPLICATED_EARLIER_DETECTION. Its current long/short Binf values differ slightly from historical numerics but satisfy the original unchanged tolerances; no old output is relabelled.

Full raw O0/O2 logs, five D6 production dependencies,152 G1 module paths plus separately linked legacy HeadCalc and fixture, all11 original postimages and nine selective qualified postimages are preserved in `integration/audits/evidence/PUB_ME_D6_G1_REGIE_QUALIFICATION_20261011.tar.gz.b64` (24 members, decoded SHA256 `d3caa9bdad344ca37c21dc51b3035850822369fb0cd69d52d7c347a86a9ff5a5`). Every member/hash and every original Git blob was verified. Production/reference and all incumbent tests/F-CI runners remain byte-identical to the live canonical base. Current owner/central #1202/#1203 full local F-CI and O0/O2 evidence is inherited; both complete archives and all12 raw log hashes reverified. Fourteen unchanged frozen F-CI refs inherit terminal SUCCESS38132433375. Original #218/#219 final-head F-CI35290039531/35290392946 remain negative. No duplicate numerical preservation or new Actions is required.

These are bounded current-evidence admissions, with zero production-capability promotions. #219 G1 means D2 directional physical replication and does not close #217 G1 complete file-driven P1-Q06 E2E. Programme G2/G3/G4/G5, whole-model equivalence, literature novelty and manuscript readiness remain owner gates. Central #486 and PUB-GC release/governance holds remain. Safe canonical publication and original-carrier closure receipts follow under the same existing registry record.

The bounded evidence successor is canonically admitted at `e2743c8b5e353c93453e1134e9f4d7884cf79dab`, tree `100c12b40ac69723cd40e37328e943c196747403`, safely leased from `31b0db16ce2f9463e316495e92e3b02faf8d4d8d`. Full fetched tree and all qualified compiled/build postimages verified. PRs #218/#219 are CLOSED/UNMERGED, original heads unchanged and branches retained; closure comments `6108818950`/`6108819227`. Those two current replay blockers are removed from the existing active publication routing, retaining their old descriptions in the closeout recovery. Fresh open queue has24 PRs:23 existing owner candidates and integration PR58. All remaining owner blocks stay explicit in the existing authorities; no new status ledger or coverage denominator is introduced.

## Ribasim historical research-carrier resolution (2026-10-11)

Reconciled original #540/#559/#581 with exact current research owner `work/ribasim-dummy-01@045ebe022856ddb72318a98edbd5237011876456` and canonical `5f9e8504c2015bc6017366e161e907b4f38125e2`. Existing registry `rom_hydro_regie_closeout_20261011.ribasim_research_resolution` is the admission/closure recovery authority; no new global ledger. This is archival research-evidence admission with zero production capabilities, no executable source/test/workflow import and no modification of active owner branches.

#540 is the completed 19I observability replay. Actual run35700016161/job106655540518 tested PR-merge `2a886ce951a5b3134f9bcf3440fc8d61e1099f29` against Ribasim pin `f965a3266a4685bf10f3458aaa1855d09fa45a7a`. At BMI call2, applied UserDemand remained32/0 rather than frozen40/7.9952; the unchanged assertion failed. The later owner record explicitly closes 19I as applied-management-clock falsification and forbids repair by tuning. It does not assert no optimization occurred. Separate19K/19L application/accepted-state equivalence evidence follows under its own source authority.

#559 is the completed 20E2 v8 full-trajectory negative fixture. Run35727480520/job106744574373 checked out exact original `19bcdc3df91b13f297fbb1bfff7da0d8095869c7` and logged all four accepted boundaries. MF6 drain flux, Ribasim drainage and cumulative groundwater transfer were zero throughout; the12h+level-reference mismatch is genuine. The owner20E2 result concludes treatment was not realized and forbids tuning frozen references or calling the management-memory hypothesis falsified. Two-cell20E3 has a separate qualified successful intervention; no retrospective qualification of20E2 follows. The old F-CI35727480533 failure also remains negative.

#581 H11 has completed terminal SUCCESS35751934131/job106828017679 despite the pre-execution qualified=false status snapshot. Actual tested checkout is PR-merge `b083975af86d53f304974b53b3836cbc6a2c4761`, not the PR head. All six preregistration/concept/generator/Julia/runner/workflow science-build blobs match original `10ff41ed84b87ed6fe691b6b944ced3c84d15099` exactly. The real pinned Ribasim v2026.1.1 `e7fc8ade52a4bedeec10e508d2065577f33eb76a` gate verifies source/release identity and all four frozen grids:

| Allocation interval | BMI call interval | Observed allocation record hours |
| --- | --- | --- |
| 4 h | 6 h | 0,12,24 |
| 5 h | 6 h | 0,30 |
| 8 h | 6 h | 0,24 |
| 6 h | 6 h | 0,6,12,18,24,30 |

This establishes the bounded fixed-dt external-release clock lattice only. It does not qualify adaptive allocation, later Ribasim releases, the actual SWAP production management hook or TOP03 composition. This is a Julia/BMI gate; no Fortran O0/O2 claim is made for that external experiment. No rerun or new download is needed to reconcile completed exact-source evidence.

All four incremental original PR postimages, original/tested stage dependencies, later owner/successor dispositions and all three complete raw job logs are preserved before closure in `integration/audits/evidence/RIBASIM_REGIE_CLOSEOUT_20261011.tar.gz.b64` (82 members; decoded SHA256 `f76e5e8b834925ad74f3b449a98e7da77ac02ae78485e5b7707551f5916577c7`). Every byte/hash and Git postimage was verified. Production/tests/reference/tools/workflows/assets remain exactly the live canonical base, so existing scientific O0/O2/F-CI is inherited without numerical reruns. Original branches remain; no new Actions, dispatches or recovery refs.

Remaining: #528 PB01 isolated sign/orientation/storage findings still need their F-GC production-contract/shared-authority disposition; no automatic sign repair. #953/#956 retain TOP03 transaction/accepted-window/external-storage/restart/numerical qualification. Actual SWAP-Ribasim management/application and scientific composition remain separately owner-controlled. Closing these historical carriers discharges none of those production gates.

Canonical evidence checkpoint `3844a7739cfee2cf6d29e1d99cb01578b24ed82d`, tree `061837dde032820e4202a389161e882aaa980fd9`, was safely leased and fetched/verified before closure. #540/#559/#581 are CLOSED/UNMERGED with original heads and branches retained; closure comments `6108932388`/`6108932708`/`6108932995`. The three former pending carrier rows are resolved by the same existing registry authority. Fresh queue:21 open PRs,20 owner candidates plus integration PR58.

### Remaining owner gates at this closeout

These are the existing decisive gates for the remaining original owner candidates, not a claim of missing sources or authorization for regie to develop production physics. Exact current heads remain the fresh PR census; detailed evidence/recovery stays in the existing owning authorities and earlier dated regie records.

| PR | Existing owner | Decisive remaining gate |
| --- | --- | --- |
| #1197 | MC-CROP01 / shared application admission | Exact owner weather/daystart/bootstrap/dispatcher postimage qualification and preservation before shared irrigation application composition. Complete crop lifecycle/joint restart remains a separate MC-CROP01 fullcap gate. |
| #1119 | PPA-WU05B frost | Recompose bounded/highest and F-CI preservation against current exact dependencies; focused normal/low-air success alone does not admit the candidate. |
| #1098, #1103, #1117 | SW431 nutrient/solute/hydraulic state owners | Owner-controlled source/layout/binding, mass and restart qualification; consolidated #1117 is a qualification carrier, not a blanket production admission proposal. |
| #1072 | SWAP431 mastercoverage | Reconcile four already admitted thermal dispositions and newest bounded irrigation/interface annotations; qualify current dependency inheritance before any global recount. |
| #1009 | F-MIG431-INT12 SWINTER1 composition | Real physical accepted-source-window/E2E proof and current crop overlap preservation; simulated FMR result is insufficient. |
| #1008 | PPA oxygen PERF03 research | Complete preregistered full Bartholomeus-route attribution; performance observation does not establish new science/production equivalence. |
| #987 | PPA RFM A27/A28 research | Q4 long-history/trusted replay/nonpublication rollback proof; opt-in approximation stays branch-only, fixed64 default/reference retained. |
| #953, #956 | SW-RIB TOP02/TOP03 shared surface/numerical/restart admission | Combined production transaction/exactly-once mass, accepted window, external body/storage ownership, transient/restart and affected preservation. Component qualification alone cannot admit either shared semantic route. |
| #740 | F-PE ELASTIC source/calibration research | Final owner disposition of unique M5 inverse-stress/20-kPa wet-state mechanical corpus and scale-transfer routing; later M1 h=-100 admission is not same-policy supersession. |
| #700 | PPA migration reconciliation | Map unique historical862-path corpus to admitted typed successors and resolve ten divergent shared production owners. Original incomplete trial does not qualify wholesale migration/source replay. |
| #528 | F-GC fixed-interface analytical/shared admission | PB01 sign/orientation/storage findings require production-contract reconciliation; isolated exact physical tangent/root proof cannot authorize changing production signs. |
| #486 | Central F-GC admission | CSR-B1-STORAGE-PARTITION and CSR-B2-DRAINAGE-OWNERSHIP; submission held, no Hupsel rerun. |
| #181, #199 | PUB-GC contract / PUB-ME literature programme | Consolidate80 unique contract and38 literature/preregistration paths; complete dated backward/forward literature closure. Research novelty remains provisional. |
| #365 | DIF-P0 research | H3 needs a second independent iterative nonlinear Richards method; RossFast cannot be relabelled. P0A binding does not close all Phase0 gates. |
| #389 | PUB-Stromingen editorial | Internal review only; owner authorship/editorial choices and current public NHI terms/status before external publication. |
| #587 | PUB-GC scientific/editorial handoff | Consolidate unique fixed-interface theory/manual draft with #486 physical authority; handoff is not production or novelty qualification. |

PUB-GC release/governance/archive/editorial R1/L1/A3/author metadata and42 placeholders remain release gates after mechanical #371 closure. Snow/thermal shared state/event timing, EB-I25/F-KT22 energy-ledger investigation, wider PUB-ME programme G1/G2/G3/G4/G5 and fullcap/application composition retain their existing separate authorities; no dummy research closure or PR count promotes those scientific dispositions.


### MC-CROP01 authentic weather production admission candidate (2026-10-11)

The existing application bootstrap now binds one authenticated daily weather-file record to hydrological forcing and crop daystart. Crop preflight consumes the previous accepted F-KT soil/thermal state before the next day's hydrology. Existing crop/WOFOST owners and the serialized runtime own physical commits, exactly-once publication and joint opaque restart; no parallel state owner is introduced.

Current-source qualification completed: twelve O0/O2 four-day continuous/restored trajectories, physical thermal-sowing and hydraulic preparation, literal historical germination and immediate WOFOST initialization, hard mass acceptance, retry/rejection and pending/delivered restart. Full moving F-CI terminated successfully with 290 distinct PASS markers; current PPA-WU03 owner and preservation both terminated successfully. Exact heads, source blobs, raw logs and the initial negative helper-identity diagnostic are preserved in `integration/audits/MC_CROP01_FILE_WEATHER_PRODUCTION_STATUS.json` and its current-production evidence archive. The F-CI93 wrapper is restored to canonical; its actual selected native oracle branch was rerun on the restored wrapper.

This qualifies the bounded root-free application API, not legacy CLI orchestration, delayed-emergence root/growth composition, harvest/rotation/fallow production or disk serialization. The four-node homogeneous soil is a qualification profile, not the Andelst reference soil trajectory. Historical task2 startup is implemented and focused-tested only on its separate recovery branch. MC-CROP01 remains ACTIVE; no master full-capability or global coverage count is promoted.

Admission receipt: PR #1204 merged exact head `e906bcee1adf4d1f6a1717ce12a5c87fdd8e1b6c` as canonical `43b912d44f7c5a22c205e0bc55c4cdfb76ae860d`. All four production blobs and the canonical exact-source guard were verified. The irrigation composition dependency now points to this admitted API; its management hook remains separately proposed. Full historical crop production and master coverage remain ACTIVE.


## Historical publication contract/literature consolidation (2026-10-11)

Reconciled canonical `43b912d44f7c5a22c205e0bc55c4cdfb76ae860d` and original #181/#199 exact heads. Selectively carry 89 previously absent publication documents as dated historical designs/results and prospective research contracts. Preserve all existing canonical results/checkpoints, including the older #199 D1 checkpoint. Earlier programme maturity/missing-source/novelty assertions are historical; frozen preregistration/specification/manifest bytes are retained. No literature verification or new scientific adjudication is claimed. Complete original publication trees (118 postimages),90 incremental PR postimages and exact blob/member hashes are archived in `integration/audits/evidence/PUBLICATION_CONTRACT_LITERATURE_CLOSEOUT_20261011.tar.gz.b64` (decoded SHA256 `b4879ff54a0e92dead6aab68805335b4e4268724794ed18a832de13ac1096496`, 121 members).

Existing registry `publication_regie_closeout_20261011.contract_literature_consolidation` owns admission/recovery; the restored historical experiment register does not create a second current global status authority. Later #217 narrowed/not-manuscript-ready adjudication and current D6/reverse-D2 qualification govern their own scopes. Original documentary carriers may close after archive/admission verification; G1/P1-Q06, G2/G3/G4/G5 remain with PUB-ME. Central F-GC #486 retains CSR-B1 storage partition and CSR-B2 drainage; release/editorial owners retain R1/L1/A3, authors and42 metadata placeholders. Other publication contracts stay prospective under named scientific owners. Zero production/fullcap/global-count promotion.

Concurrent owner admission #1204 is canonical at `43b912d44f7c5a22c205e0bc55c4cdfb76ae860d`; owner closed #1197 as its superseded original carrier. Regie verified the current archive SHA256 and all five complete raw logs, including the original negative helper diagnostic; canonical `src` equals both current full-moving and Wu03 qualified source trees `87fc3103f07b1ee8b39aa4a1780731c4b8e13d9f`. The restored FCI93 wrapper was explicitly replayed by Wu03. Four later publication test/build files do not change crop graphs. The earlier219-path compile manifest retains one historical HeadCalc blob; current evidence is the later exact-source qualification, not invented equality of that earlier manifest. Correct the existing registry's pre-merge admission-pending field. Root-free authentic weather/accepted thermal daystart/immediate emergence is admitted; delayed emergence/root/growth, CLI/lifecycle and disk continuation remain with MC-CROP01. Shared irrigation/application hook admission remains its distinct owner gate.

Local persisted documentary qualification passed: documentation source checks, strict MkDocs, YAML/JSON, whitespace, all121 archive members and all118 original Git postimages. All frozen preregistration bytes and six source/test/reference/tool/workflow/asset subtrees remain exact. This qualifies the archival documentation admission only; no scientific claim, hypothesis, tolerance or production code changed.


### Verified publication stack closure

Historical #181/#199 are CLOSED/UNMERGED after canonical admission `3bf921f50539284652d9bd1b136388947320f9c4` (tree `51a4ea1b5e2d0aa56dfe77aecb0bf59a5270162c`) was fetched and fully verified. Comments6109113348/6109113608 bind original heads and archive. Existing registry removes both from active PR routing while retaining the real PUB-ME G1-G5 scientific/literature owners. Fresh queue:18 PRs,17 owner candidates plus integration58. Zero new Actions at the admission head. The concurrent owner8973c710 crop-status/application-dependency receipt was retained intact.

### Fixed-interface editorial transfer — archival successor

#587 is a completed two-document editorial handoff at `ff93b7829b2f0bf4de4987cd249bdfc94fe05cb3`. Preserve both exact original postimages, the complete current manuscript before annotation and PR provenance in `integration/audits/evidence/PUB_GC_THEORY_HANDOFF_CLOSEOUT_20261011.tar.gz.b64` (decoded SHA256 `35fc92668810d008ce04d5d50de8c3df95628f935e453811dff6f5a0dfaae394`, 5 members). Select the missing dated handoff and a scoped manuscript link/submission-hold annotation; no substantive mathematical/Methods revision or new scientific verdict. Existing manuscript bytes and negative E7 interpretation remain intact. The historical claim of closed storage/process ownership is not today's authority: central #486 retains CSR-B1/CSR-B2, and manuscript/theory owners retain mathematical-context, novelty/literature and final editorial revision. Submission/release holds and no-Hupsel-rerun guard remain explicit. Existing registry `publication_regie_closeout_20261011.theory_handoff_closeout` owns recovery.


### Verified theory handoff closure and current remaining owners

The bounded archival successor is canonical at `cfbd81b61e2ef5462ef4b719be0bc2ee02e80e9e`, tree `9ae690af3557334d3ef70755b81d7c4bbd043ab2`, fetched and verified before original #587 closure. #587 is CLOSED/UNMERGED, original `ff93b7829b2f0bf4de4987cd249bdfc94fe05cb3` and branch retained, comment6109146606. All five archive members, both exact original postimages and complete incumbent manuscript verified. Documentation source/strict MkDocs, JSON/whitespace and six unchanged science/execution subtrees pass. No Actions at either new archival admission; no dispatches or recovery refs. Existing registry routes actual scientific/editorial gates independently of the now-closed documentary carriers.

After verified guard1119 admission/closure, fresh queue has16 PRs:15 owner candidates and canonical integration58. Exact current heads/branches are persisted under existing `finalization_frost_regie_closeout_20261011.nan_guard_admission.fresh_open_pr_census`. This table supersedes only earlier active-carrier routing; historical dispositions/evidence stay intact.

| Open PR | Existing owner | Actual remaining admission/closure gate |
| --- | --- | --- |
| #1098, #1103, #1117 | SW431 nutrient/solute/hydraulic owners | Owned source/layout/binding, mass/restart qualification and exact production-admission proposal; consolidated qualification is not blanket admission. |
| #1072 | SWAP431 mastercoverage | Current8dbed749 reconciles eleven accepted-salt/allocation irrigation annotations, retaining counts. Global integrity is explicitly not renewed because inherited baseline is stale; owner must qualify current global inheritance and reconcile four thermal/crop/guard dispositions before recount. |
| #1009 | F-MIG431-INT12 SWINTER1 | Actual physical accepted-source-window/E2E composition and preservation against admitted crop1204; simulated FMR evidence is insufficient. |
| #1008 | PPA oxygen PERF03 | Full preregistered Bartholomeus-route attribution and scientific equivalence; no general performance claim. |
| #987 | PPA RFM A27/A28 | Q4 long-history/trusted replay/nonpublication rollback; fixed64 default retained, opt-in approximation branch-only. |
| #953, #956 | SW-RIB TOP02/TOP03 shared admission | Combined exactly-once transaction/mass, accepted-window/external-body/storage, transient/restart and numerical preservation. |
| #740 | F-PE ELASTIC source/calibration | Final disposition of unique M5 inverse20-kPa corpus/scale transfer; admitted M1 h=-100 is not same-policy supersession. |
| #700 | PPA migration reconciliation | Map862 historical paths to typed successors; ten divergent shared source owners require disposition before any wholesale replay. |
| #528 | F-GC fixed-interface research/shared authority | PB01 sign/orientation/storage production-contract reconciliation by central F-GC; isolated roots/tangents cannot authorize sign repair. |
| #486 | Central F-GC | CSR-B1-STORAGE-PARTITION and CSR-B2-DRAINAGE-OWNERSHIP. Submission held; no Hupsel rerun. |
| #365 | DIF-P0 | Independent second iterative nonlinear Richards method for H3; RossFast is a different formulation. P0A is not full Phase0. |
| #389 | PUB-Stromingen editorial | Internal review; current public NHI terms/status and owner authorship/editorial decisions before external publication. |

Owners without an open historical carrier remain explicit: PUB-ME G1/P1-Q06,G2 checkpoint/restore/rerun,G3 warm-start,G4 additional hydrologic replication,G5 dated literature/final novelty; PUB-GC substantive mathematical-context/Methods revision and literature/novelty; PUB-GC R1/L1/A3, authors and42 finalization placeholders. MC-CROP01 retains grown-root/delayed-emergence/whole lifecycle/CLI/disk continuation. MC-IRR01 runtime salt/allocation is admitted; shared management application-hook/root-free and rooted weather/crop/event joint continuation remain with central RT/HY and MC-CROP01 under the existing precise contract. Snow/thermal shared state/event timing and EB-I25/F-KT22 energy ledger retain existing central/thermal owners. No new production physics, fullcap promotion or global coverage count.


## PPA-WU05B existing invalid-input guard qualification (2026-10-11)

Reconcile original #1119 `2f1b90d05746341ff9acfbf3276a8ee6d5a12b01` onto live canonical `1a159c316a97e3870accce32f657f34bcaa59c8b`. Only the existing two nonfinite preflight hunks are selected: exact frost-effect blob `0dd5b541af936d292d23575f798c3cdd5be19c47`. No finite-input formula, residual conductivity, threshold, derivative, layout, interface, state owner or numerical budget changes. This is bounded robustness admission, not new production physics or aggregate frost completion.

Original invalid-input, provider/effect and bounded physical/retry/restart O0/O2 pass. Independent33 quiet-NaN/+Inf/-Inf array/active-parameter cases preserve input bits atomically at O0/O2; canonical predecessor reproduces O0 SIGFPE136. Both complete highest routes run the sealed unchanged B15 science/build/flags/oracles/budgets:24 full configurations,144 fine comparisons and complete O0/O2 output identity. Only exact source admission and owned scratch prefix differ. All222 Git compile dependencies are unchanged by concurrent allocation #1205; generated low-air grid is separately preserved.

Full moving preservation on persisted `5bb1b2e61` (byte-equal remote `e57d220116674e61ff0d570aa0a39328c00edcae`) reaches terminal exit0 including allocation preservation. Current affected crop/weather/thermal/B19 and allocation-negative O0/O2 also pass. Final F-CI body equals the executed version after exactly two stronger immutable-archive preflight substitutions; those new gates and the additive exact crop source census were separately verified. This is explicit dependency inheritance, not a claim that the final wrapper was invoked in the whole run.

Complete archive `integration/audits/evidence/FROST_NAN_GUARD_QUALIFICATION_20261011.tar.gz.b64` has90 verified members, decoded SHA256 `f7b95b481c3d2f389647a52a74ce7f152b2c8dae365a6748d72df92537e5f316`, all5 original postimages,223 dependency entries,24 complete configuration stdout/stderr sets and12 raw local logs. Four old failed job logs retain actual PR merge checkout `f8e8f4333de07e408edd33e45982f84c4de8080b`: highest source-pin failures precede execution; bounded/moving failures are exact B19+MICRO tree admission. They remain negative. Every tested remote checkpoint is retained through Git recovery ancestry. Existing `finalization_frost_regie_closeout_20261011.nan_guard_admission` and owning `PPA_WU05B_NAN_GUARD_STATUS.json` hold admission/recovery; no new global ledger.

Concurrent #1205 source/fixtures/workflow/archive and later owner records are retained: five owner status/disposition/closure/composition files stay byte-exact; owner additions in PROJECT-CONTROL/registry stay unchanged beneath additive regie receipts. The latest root-free and rooted management application proposals remain with central RT/HY and MC-CROP01; allocation is no longer an implementation-absence claim. Zero fullcap or global coverage count change; aggregate frost remains incomplete under its existing owner authority.

### Verified guard admission and closure receipt

Canonical merge `da9ef1e5d37cd49f996dc48e24fcd09110cff777`, complete tree `fb9ebb5a29fde914bbc1802e5a85f0a71e10379d`, was safely leased from1a159c316, fetched and verified before closure reporting. GitHub #1119 is CLOSED/MERGED with exact original2f1b90d retained as merge parent and branch unchanged; closure comment6109956306. All historical tested checkpoints remain reachable through8dc07bf65 recovery ancestry. Canonical immutable archive/source and crop census verification, documentation source/strict MkDocs, JSON/whitespace pass. Source changes only the two original guard hunks; no new Actions at the admission head. Dedicated guard blocker is resolved; aggregate frost is not promoted.

Fresh census has15 remaining original owner candidates and integration58. Master owner handoff6109956480 records zero count delta. Live master head8dbed749 has its bounded eleven-row irrigation update, but its own evidence explicitly retains pre-existing stale global inherited authority/checker failure; four thermal and current crop/guard coverage reconciliation remain with that owner. No active master, specialized source or count files are overwritten. The exact remaining gates and owners are the table above plus the existing shared/application/publication authorities.

## MC-IRR01 independent runtime closeout and exact shared application gate (2026-10-11)

Canonical allocation PR #1205 (`cd530867dc8a41e8cd5b46dfbaff1007d14c3a75`) admits persistent external provider identity/fraction/window, frozen in-flight receipt, fresh next-event selection and physical/event/allocation restart. Real root24 and sensor12 O0/O2, fresh next events, atomic invalid receipt/availability guards and complete current moving preservation passed. PR1203 already admits accepted matrix salt CML; PR1200/1201 admit realistic retained-history source onset/off. No duplicate irrigation, crop or solute physics. Exact crop source census recognizes only the new known irrigation blob; all219 crop compile/runner dependencies remain unchanged.

All original16 dispositions are in `integration/audits/MC_IRR01_CAPABILITY_DISPOSITIONS_20261011.json`:5 fullcaps ADMITTED,11 ACTIVE with explicit shared application authority gate. PR1204 weather API remains root-free/bottom7 and rejects positive transpiration/root extraction; it does not admit a management hook or evolved-root irrigation. Central RT/HY and MC-CROP01 owners must accept the proposed shared management hook and grown-root/weather profile, derive evolved roots and material thresholds from existing accepted owners, compose real rain/ET/daystart, and qualify joint physical/weather/crop/irrigation weekly/event/allocation restart at O0/O2 with affected owner/F-CI preservation. Reuse admitted runtime bindings; do not implement a second crop/root owner. This is the remaining central/MC-CROP01 dependency, not absent legacy archives or salt/allocation processes. No full MC-IRR01 or global master coverage closure claim.


## PPA-RECONCILE01 complete historical path inventory (2026-10-11)

Central regie resumes at canonical `8216240ddcbfcf1c8ea44219cc7149f90fa9408c` and original PR #700 head `5fcd9769c30379f461ce047f410638b0d3311f96`. The live GitHub queue agrees with the prior frost closeout: fifteen owner candidates plus intentional integration #58. No new admission-ready owner proposal was found. Existing owner branches and scientific blockers are retained.

The original merge-base delta contains exactly 862 paths: 773 pathnames absent at this canonical snapshot and 89 divergent postimages. Of 160 source paths, 150 are absent and ten diverge. Zero historical source blobs have exact byte-identical locators anywhere in the current tree. Nine source files retain module-name locators and ten have unique named-declaration locators. Those are lexical navigation findings, not demonstrated scientific successors. Absence of a historical filename does not establish absent physics.

The complete per-path inventory, historical and current Git identities, historical source declarations/imports, owner routes and pinned current review entrypoints are in `integration/audits/PPA_RECONCILE01_CURRENT_LINEAGE_20261011.json`. The twelve source owner routes cover all160 source paths: macropore58, irrigation27, solute21, lower-boundary15, weather/interception14, shared-solver9, shared-runtime5, oxygen4, compensated-root2, frost2, micro2 and salinity1. These are review-routing counts, not capability counts. Current solute entrypoints cover bounded admitted salt/transport; they do not establish migration of historical age or reactive processes.

The ten divergent shared paths are the existing Richards legacy binding, HeadCalc, irrigation process, committed restart, application bootstrap, restart-state contract, serialized MultiSWAP runtime, serialized reference backend, temporal indicator and solver contract. A whole-tree merge would replace current accepted contracts with the old branch. Their current locators and exact blobs are recorded separately from historical ones; solver, runtime, crop, irrigation, solute and macropore owners must adjudicate proposed recovery before any source replay. Original WU04C remains a negative historical trial (`completed=false`, `committed=false`); declaration matching and this audit do not resolve it.

All862 original postimages are preserved byte-exact in `integration/audits/evidence/PPA_RECONCILE01_ORIGINAL_POSTIMAGES_20261011.tar.gz.b64`, plus an internal manifest (863 members; decoded SHA256 `5a0e47c8ceb9df9f87030f42a0c87e06a4f338510eecc0eec8c30fe11381ab5c`). The deterministic reproducer is `tools/verification/reconcile_ppa_reconcile01.py`; regeneration is bounded to exact historical and canonical refs. Run it with `--canonical 8216240ddcbfcf1c8ea44219cc7149f90fa9408c --verify` to check the complete Git-backed report/archive.

Existing registry `owner_research_reconciliation_20261011.keep_open[pr=700].current_lineage_audit_20261011` owns recovery and qualification. This is a mechanical archival/routing successor only. PR #700 remains open, owner branches remain unchanged, and no source, fixture, numerical tolerance, physical capability disposition or global count is promoted. No physical test or preservation rerun is claimed by this checkpoint.
