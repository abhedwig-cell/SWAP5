# SWAP5 Project Control

**Work unit:** PROJECT-CONTROL-01  
**Control snapshot:** `integration/f-ci-canonical@3a815edda7cf5e155272b68ae49d440fd5db9138`  
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

## Control model

Specialized workstreams may research, implement and qualify inside their declared ownership. They do not acquire canonical authority merely by producing a branch or PR.

The common admission path is:

`READY_FOR_REGIE -> RECONCILE -> ADMIT | RETURN | SUPERSEDE`

Central regie owns canonical admission, cross-workstream supersession, shared-authority reconciliation, preservation repair and repository-level routing. Central regie does not develop new hydrological physics, solver functionality, groundwater coupling methods or production ROM functionality.

## Current project map

| Workstream | State | Current authority / finding | Next gate |
|---|---|---|---|
| REGIE | ACTIVE | canonical snapshot `3a815ed`; PR #58 remains the intentional carrier; F-TA04R resolves the last old housekeeping item #172 on this admission; #486 is blocked shared-authority repair rather than admission-ready work | After F-TA04R, wait for qualified specialized admission candidates or explicit preservation/shared-authority work |
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

F-TA04R is the final recomposed successor for the old central housekeeping queue. It registers bounded A23BL and pinned F-TB11 transaction/restart traceability and adds a fail-closed catalog-locator check. On successful exact-head qualification and admission, historical PR #172 becomes superseded and the old #72/#163/#172 queue is empty.

### Testbank preservation

F-TB13R is an additive current-canonical rebase of the qualified analytical/reference package from PR #163. Its preserved archive, member identities, replay receipt and checker are imported unchanged; a new reconciliation record binds them to current B1.11 and requires fresh dedicated F-TB13, Documentation, VQ and F-CI qualification. It does not rewrite F-TB11/F-TB12 or claim SWAP5 production-solver equivalence.

### Transaction/restart traceability

F-TA04R recomposes historical PR #172 against current canonical. It does not change transaction or restart behaviour. It records two complete bounded catalog entries:

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

F-TA04R is the final item from the old #72/#163/#172 housekeeping queue. After its admission, central regie should not invent a new generic cleanup task. The next central action should be triggered by a genuinely qualified specialized admission candidate, explicit preservation drift, project-control refresh, or a shared-authority conflict. PR #486 remains blocked until its storage/drainage authority is resolved.

This ordering is a routing decision, not a scientific priority ranking.
