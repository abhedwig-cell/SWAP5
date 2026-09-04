# Implementation status map

**Snapshot:** 2026-09-04  
**Scope:** transition from the SWAP 4.3.1 baseline toward the SWAP5 target architecture

This page is the central status register for the SWAP5 architecture. It separates architectural intent from implementation and qualification evidence.

!!! warning "Status is evidence-based"
    A target design is not treated as implemented merely because it is described in an ADR or architecture page. Likewise, active refactoring work is marked `IN_PROGRESS` until it is integrated and qualified. The current `SWAP5` repository is still documentation-led; several implementation statements below refer to active audit/refactoring work that has not yet been mirrored into this repository as production source.

## Status vocabulary

| Status | Meaning |
| --- | --- |
| `BASELINE` | Behaviour or structure exists in SWAP 4.3.1 and is being used as the reference or migration source. |
| `TARGET` | Accepted target architecture, but no integrated production implementation has yet been demonstrated. |
| `PARTIAL` | A prototype, interface, adapter, testbank or limited implementation exists, but the capability is not end-to-end. |
| `IN_PROGRESS` | Active implementation/refactoring exists, but the migration or qualification is incomplete. |
| `QUALIFIED` | An implementation has passed an explicit reference/verification gate for its stated scope. |

`QUALIFIED` always applies to a stated scope. It must not be read as a claim that the entire SWAP5 architecture is qualified.

## Current architecture-to-implementation matrix

| Capability | Status | Current evidence / position | Required next proof | Invariants |
| --- | --- | --- | --- | --- |
| One computational kernel for standalone, MultiSWAP and coupling | `TARGET` | Accepted architectural contract. The 4.3.1 baseline is still a legacy program structure rather than the final reusable kernel. | Integrated kernel API used by at least standalone and one multi-column or coupling path without duplicate physics. | 1, 16 |
| Kernel independent of file I/O | `TARGET` | Boundary is documented and accepted. Legacy 4.3.1 remains file-oriented and is the migration baseline. | Kernel execution from typed in-memory inputs with legacy file handling demonstrably outside the kernel. | 2, 28, 29 |
| Explicit separation of parameters, state, forcing, numerical policy and results | `IN_PROGRESS` | Current refactoring around solver and `headcalc` state is explicitly pulling global/mixed state apart. Data ownership contract is documented. | Integrated types/interfaces with ownership tests and no hidden cross-category mutation. | 3, 4, 5 |
| Compact persistent per-column state | `IN_PROGRESS` | State reduction is an explicit migration objective; recent transactional work removed redundant endpoint/snapshot copies. | Per-template state inventory plus measured memory footprint showing inactive options allocate no persistent state. | 4, 27 |
| Worker-owned Newton/Jacobian scratch | `IN_PROGRESS` | ADR-0003 is accepted and current solver-state refactoring is moving temporary solver data away from permanent column ownership. | Multi-column/order-independence tests with scratch reuse and no cross-column contamination. | 5, 6, 16 |
| Scalable batch/SoA-compatible storage | `TARGET` | Logical API permits SoA, pools and batches, but no qualified production storage layout is yet recorded here. | Batch implementation with memory and throughput measurements on representative large column sets. | 6, 16, 27 |
| Transactional checkpoint, trial, retry, commit/rollback | `IN_PROGRESS` | A `TrialResult`-style commit layer and step-doubling/transactional refactors exist in active work. Redundant endpoint copies have already been removed. Legacy orchestration extraction is still ongoing. | End-to-end rollback/retry tests proving rejected trials cannot mutate committed physical state. | 7, 8, 13, 26 |
| Solver retry policy separated from legacy control flow | `IN_PROGRESS` | Active refactoring is moving timestep reduction and solver-attempt status behind retry/execution policy adapters. | `swap.f90` no longer owns solver-specific retry orchestration; retry decisions are testable independently. | 7, 23, 24, 29 |
| Cheap rerun and warm-start contract | `TARGET` | Physical and numerical state distinction is documented; warm starts may reuse trial numerics but correctors must start from committed physics. | Repeat-run tests from identical committed state with changed boundaries and identical mass accounting. | 8, 11 |
| Generic kernel time interval `[t0,t1]` | `TARGET` | Accepted architecture. Legacy assumptions about day/calendar control have not yet been demonstrated as fully removed. | Tests with non-midnight starts, non-day intervals and independent forcing/reporting/coupling boundaries. | 9, 10, 29 |
| Flexible MODFLOW coupling windows | `PARTIAL` | API/coupler design and a bidirectional dummy-aquifer testbank have been developed, but this is not yet the integrated production runtime. | Predictor-corrector tests over variable coupling windows, including rollback and retry. | 10, 11, 15 |
| Groundwater interface contract `H_SWAP = H_MF`, `q_SWAP = -q_MF` | `TARGET` | Contract is normative and documented. | Coupled benchmark with explicit head residual tolerance and machine-auditable interface water balance. | 12, 13 |
| Mass conservation as a hard acceptance condition | `PARTIAL` | It is a normative invariant and central audit criterion. Individual fixes/experiments are water-balance checked, but a universal SWAP5 runtime gate is not yet present. | Automated balance gate covering normal, retry, fallback, standalone and coupled execution paths. | 13, 19, 24 |
| Interface sensitivities such as `dh_b/dq_b` as first-class output | `TARGET` | Desired API is defined. Existing derivative audit work such as qualified `dK/dh` improvements is useful numerical groundwork but is not itself the required coupling response tangent. | Solver API returns qualified interface tangent from the production Jacobian/factorisation, with finite-difference reference tests. | 14, 15 |
| Predictor + corrector as normal coupling cost path | `TARGET` | Cost objective is accepted; perturbation runs are reference/fallback only. | Coupling benchmark showing normal windows do not structurally require 6–9 full SWAP solves. | 14, 15 |
| MultiSWAP homogeneous model templates / execution classes | `TARGET` | ADR-0004 is accepted. Template semantics and separation of physical topology from numerical execution class are defined. | Runtime batches columns by template and can reroute difficult columns without changing physics. | 6, 16, 23, 24, 27 |
| Multiple surface tiles per MODFLOW cell | `TARGET` | Runtime/coupler ownership and area-weighted aggregation are architecturally defined. | Coupler test with fractions summing to one and conservative aggregation of tile fluxes. | 17, 28 |
| Optional deep-vadose transfer component outside SWAP | `TARGET` | Component boundary and minimal storage/transfer model are defined conceptually. | Standalone transfer-zone component with storage continuity tests, including transitions to/from direct coupling. | 18, 19, 28 |
| Common soil-water interface for alternative solvers | `TARGET` | Required abstraction is defined. Full Richards remains the functional reference; coarse/reduced-order alternatives are not yet integrated behind one production interface. | Two solver implementations exercised through the same interface against shared physics and reference cases. | 20, 21, 22, 25 |
| Other modules isolated from `HeadCalc` internals | `IN_PROGRESS` | This is a direct objective of the current S12 refactoring, which is systematically extracting global state and hydraulic dependencies around `headcalc`. | Dependency review showing crop, ET, drainage and other modules use a clean hydraulic contract rather than solver-internal arrays. | 21, 22 |
| Physical options separated from numerical solver policy | `TARGET` | Architectural distinction is accepted, including reference/balanced/throughput execution policies. | Configuration/API tests proving policy changes cannot silently enable, disable or alter physical modules. | 23, 25 |
| Bounded-cost solving and qualified fallback ladder | `TARGET` | Required for difficult columns such as heavy-clay cases, but a general production fallback ladder is not yet qualified. | Reference-vs-fallback qualification with hard mass balance, bounded deviation and per-column cost diagnostics. | 24, 25, 26 |
| Full-accuracy reference mode | `PARTIAL` | The technical audit already uses explicit reference baselines and strict qualification for individual solver changes, including prior `dK/dh` work. A unified SWAP5 runtime reference mode is not yet demonstrated. | One runtime-selectable reference policy used as the qualification baseline for all new numerical variants. | 25 |
| Runtime diagnostics for mode, retries, cost and water balance | `TARGET` | Diagnostic requirements are explicit but no complete per-column runtime schema is yet qualified. | Stable result/diagnostic schema populated for normal, relaxed and fallback execution. | 24, 26 |
| Optional physics incurs cost only when active | `TARGET` | Required by template/state design; no comprehensive memory/compute proof is yet recorded. | Template-level memory and timing evidence for optional modules such as macropores and special drainage. | 4, 27 |
| System composition owned by runtime/coupler | `PARTIAL` | API/coupler prototypes already place MODFLOW relationships outside the SWAP physics kernel. Production composition is still to be integrated. | End-to-end multi-tile/coupled run where kernel has no knowledge of MODFLOW cell fractions or transfer-zone routing. | 17, 18, 28 |
| Removal of silent day/file/MODFLOW assumptions | `IN_PROGRESS` | Transaction orchestration and data-boundary refactoring are explicitly attacking legacy control-flow dependencies, but the full codebase has not yet been cleared. | Static/code review plus tests for non-midnight, in-memory and standalone execution paths. | 2, 9, 29 |
| Architecture changes traced to invariants and verification | `PARTIAL` | The 30 invariants, ADR process, verification principles and this implementation map are now part of the versioned documentation. Enforcement in code-change CI is not yet complete. | Pull-request/change template or automated gate requiring affected invariants and qualification evidence for material architecture changes. | 30 |

## Qualified work is narrower than architecture status

Some technical audit items can be fully qualified without making an entire architecture capability `QUALIFIED`. For example, a solver derivative fix may pass strict regression and performance gates while the broader soil-water interface is still being redesigned.

The status map therefore tracks **architectural capability**, not the number of successful patches.

## Update rule

A row may move forward only when the evidence changes:

1. `TARGET` → `PARTIAL` when a concrete prototype/interface/testbank exists;
2. `PARTIAL` → `IN_PROGRESS` when it becomes part of the active production migration;
3. `IN_PROGRESS` → `QUALIFIED` only after explicit integration and reference verification for the stated scope.

Regression or newly discovered hidden dependencies may move a row backward. Status is descriptive, not a project-management promise.

## Relationship to the migration work

This map is deliberately broader than one refactoring series. The current transactional solver/controller work and the `headcalc` state-extraction work should both update this register as their evidence changes. Future component and legacy-to-target maps should use the same status vocabulary so architecture, implementation and verification remain traceable.
