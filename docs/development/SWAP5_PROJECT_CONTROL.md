# SWAP5 Project Control

**Work unit:** PROJECT-CONTROL-01  
**Control snapshot:** `integration/f-ci-canonical@09b6d0415fee3c63c71ecd11b215fe0d206e05ae`  
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
| REGIE | ACTIVE | canonical snapshot `09b6d04`; PR #58 remains the intentional carrier; #72/#163/#172 are reconciliation debt | Process live admissions first; otherwise reconcile #72, then #163/#172 in bounded slices |
| PPA production physics | ACTIVE | WU04-A Black, ROOT-HYD02 prescribed-root tangent and WU04-B Boesten are already merged to canonical; WU05-A/C are review-only authority | Production owner selects the next source-authorized bounded slice; no inference from review authority to production |
| F-GC groundwater coupling | BLOCKED_EXTERNAL | F-GC50 is internally ready; PPA-WU01 resolved the former internal bootstrap blocker | Wait for a real authorized upstream iMOD Coupler driver/config extension route |
| F-ROM / LARE | BLOCKED_EXTERNAL | D31 confirms official M2WC70 archive metadata but cannot materialize the implementation oracle; D28 native-ET blocker also remains | Materialize acceptable FMC implementation authority or narrow/close the affected proposition |
| HYDRO-MEMORY | ACTIVE | live root-active SWAP-MODFLOW6 passed one window and four consecutive windows; DYN01 forcing + state-dependent Feddes composition passed | Stage 0 remains unauthorized; continue remaining dynamic composition and soil/diagnostic freeze under research ownership |
| DIFFICULTY | OWNER_CONTROLLED | Phase-0 preregistration exists in PR #365 | Continue prospective research; independent nonlinear-method comparison remains separately gated |
| TRACE | ACTIVE | protocol, candidate register, Batch 02 closeout and Batch 03 are canonical | Continue prospectively; feed only shared governance implications back to regie |
| Publications | OWNER_CONTROLLED | PUB-GC E7 remains closed as a realistic component-domain limit; later research evidence does not itself widen production ownership | Reconcile publication tooling to current canonical; explicit archive/release metadata remains separate |

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

F-GC50 is not waiting on another internal SWAP5 architecture redesign. Its current state is `CANONICAL_INTERNAL_READY_EXTERNAL_B1_BLOCKED`. The remaining product-integration blocker is external: a real iMOD Coupler driver/config registration route requires upstream mutation/extension authority.

HYDRO-MEMORY live coupling evidence does not remove this product-integration boundary.

### ROM

The live ROM authority is F-ROMV2, not the old F-ROM0 draft PR.

D30 established that the natural within-step surface-front/groundwater-front contact transition is not sufficiently specified from the paper-level authority alone. D31 found the official M2WC70 archive metadata, but the archive could not be materialized and no equivalent traceable oracle was found.

Therefore there is still:

- no contact-capable long-window trajectory;
- no application acceptance;
- no formal performance claim;
- no production ROM.

### HYDRO-MEMORY

The old CAP-gate PRs no longer describe the complete live state.

Canonical now contains:

- ACC02-F1: live root-active single-window coupling PASS;
- ACC02-F2: four consecutive live root-active windows PASS;
- DYN01: forcing plus accepted-state-dependent restricted Feddes composition PASS.

This is substantial research capability evidence, but **Stage 0 is still not authorized** and this research route does not silently widen the production application owner.

## Open PR routing

### Central reconciliation queue

These are the only old PRs that central regie should actively recompose when no newer admission is waiting:

- **#72** Status-A to Status-AA governance: reconcile useful principles against current governance; do not merge the stale branch as-is.
- **#163** F-TB13 analytical reference preservation: reconcile against current F-TB authority.
- **#172** F-TA04 transaction/restart traceability: reconcile against current transaction/restart authority.

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

> Continue F-GC from live canonical and the PROJECT-CONTROL registry. Treat F-GC50 as internally ready and externally blocked unless upstream product authority has changed. Do not invent a local iMOD Coupler product loop or transfer SWAP/FMR state ownership to Python. Return only genuinely new product-integration authority to central regie.

### ROM continuation header

> Continue F-ROMV2 from live canonical and the PROJECT-CONTROL registry. No production ROM and no Reference/RossFast mutation. Preserve D28-D31 blockers exactly. Proceed only with evidence that can resolve or narrow the implementation-authority gaps, and return shared canonical implications to central regie.

### HYDRO-MEMORY continuation header

> Continue HYDRO-MEMORY from live canonical and the PROJECT-CONTROL registry. Treat ACC02-F1/F2 and DYN01 as current evidence, but keep Stage 0 unauthorized until the remaining preregistered gates are closed. Research evidence does not widen production ownership by implication.

### Publication continuation header

> Continue the named publication workstream from live canonical and the PROJECT-CONTROL registry. Publications consume canonical science and capability; they do not create production authority. Rebind stale tooling/evidence to current canonical and return only shared preservation/admission changes to central regie.

## Default next action for central regie

When no specialized workstream has a genuinely admission-ready successor, the next safe control task is **#72 governance reconciliation**, followed by #163 and #172. Each should be recomposed against current canonical rather than replaying an old branch.

This ordering is a routing decision, not a scientific priority ranking.
