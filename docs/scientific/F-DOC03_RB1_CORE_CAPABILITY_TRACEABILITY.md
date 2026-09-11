# F-DOC03 RB1 core capability traceability

## Scope

F-DOC03 is the first capability-specific population under the F-DOC01 T0-T14 architecture and the F-DOC02 fixed RB1 release index. It covers exactly five required RB1 capabilities:

- `RB1-CORE-INTERVAL`
- `RB1-CORE-DATA`
- `RB1-CORE-TRANSACTION`
- `RB1-CORE-MASS`
- `RB1-CORE-DIAGNOSTICS`

The machine-readable authority for this tranche is `docs/scientific/registries/rb1-core-capability-traceability.json`.

F-DOC03 is documentation and traceability only. It does not change production source, reference data, physics, solver behaviour, acceptance thresholds, performance policy, the fixed 15-capability RB1 denominator or the immutable RB1 release authority.

## Authority pins

- F-DOC01 architecture: `999d4fa3da6fa08c5d57e23b9949f3920de37fbe`
- F-DOC02 release-bound index: `18942fee83eb385fccc1663230772ae03dcc9ae6`
- RB1 scientific source authority: `0aeb0a2ed4096e1f9493d3dabc70962ea5270182`, tree `c77ac75aea522ac20a60da012595af9166efcff6`
- F-RB01 qualification authority: `aeb74560d801c4ac7314df7b8845fcc5daf8bba6`
- F-RB02 final release authority: `b52e4dc5ff1c16ccaf11853cc085c7099e17ccc0`, exact-head run `34586202805`

The exact frozen implementation mappings use:

- `src/runtime/mod_canonical_contracts.f90`, blob `c06aa869a0bd479df4c7d6e1d0b4f5c07a207144`
- `src/runtime/mod_canonical_interval_runtime.f90`, blob `55f3d271aa6200a994fd0144d6fce0701c918a74`
- `src/transaction/mod_transaction_reference.f90` at the same frozen source authority

## Classification rule

F-DOC01 explicitly allows important production code to be classified as non-scientific infrastructure rather than inventing a reverse physical-theory chain. F-DOC03 applies that rule narrowly.

`RB1-CORE-DATA` is software-architecture infrastructure. `RB1-CORE-INTERVAL`, `RB1-CORE-TRANSACTION` and `RB1-CORE-DIAGNOSTICS` are runtime infrastructure with applicable algorithmic/numerical tiers where their behaviour is real and observable. Their non-applicable physical/scientific tiers are recorded with capability-specific rationales.

`RB1-CORE-MASS` is different. It is a scientific conservation capability as well as runtime accounting, so F-DOC03 does not classify T0-T8 away. It records the physical storage/flux phenomenon, the accepted-state ledger, the interval balance equation, accepted-only formulation, discretised aggregation, hard mass gate, algorithm, software contract and exact implementation mapping.

## Core mass equation and accepted-only semantics

For the canonical interval ledger the frozen implementation evaluates

`R = (S_end - S_start) - (Q_in - Q_out)`

where `Q_in` and `Q_out` are interval amounts accumulated only from accepted transactions. Rejected trials never enter the authoritative interval ledger. Missing contribution flags, non-finite terms or absent accepted transactions prevent the interval mass account from being marked complete.

The transaction core separately applies a hard per-trial mass residual gate before a trial can be accepted. F-RB01 then requires hard mass conservation as a release gate across the admitted serial, restart and restricted parallel profiles.

This documentation does not change the equation or tolerance. It names and links behaviour already present in the frozen RB1 source.

## Explicit remaining gaps

F-DOC03 intentionally does not claim a complete traceability closure.

For `RB1-CORE-MASS`, T1 remains an explicit gap because this workunit does not fabricate or retroactively select an independent controlled scientific source for the conservation principle. The operational principle is already mandatory in RB1, but the controlled theory/source citation still needs reconciliation.

For all five capabilities, T11 remains `SCOPED_EVIDENCE_LINKED_NOT_FULLY_TRACED`. F-RB01 and F-DOC02 provide authoritative qualification and verification locators, but this workunit does not pretend that those release gates constitute a complete field-by-field or equation-to-test verification graph.

T12 is classified `NOT_APPLICABLE` for these core infrastructure/conservation contracts with explicit rationale. Observational validation belongs to the physical process/application capabilities feeding the runtime, not to transaction atomicity, data ownership, diagnostics aggregation or the bookkeeping identity itself.

## Correction recorded during F-DOC03

A preliminary search assumed a frozen test path `tests/runtime/test_canonical_runtime.f90`. Live inspection of the RB1 source authority showed that this file does not exist there; `tests/runtime/` contains `test_a23bu_worker_context.f90` only. F-DOC03 therefore does not cite the nonexistent path and does not manufacture a direct unit-test binding. The T11 records stay scoped/provisional and point to the actual F-RB01/F-DOC02 qualification evidence.

## Release and Status A/AA boundaries

F-DOC03 does not claim that any of these five capabilities is `FULLY_TRACED`, `READY_FOR_STATUS_A_REVIEW`, Status A compliant or Status AA compliant. F-DOC03 also does not turn an RB1 PASS into missing theory, source provenance or application validation.

The rest of the 15-capability RB1 denominator remains governed by F-DOC02 and is not populated by inference from this tranche.

## Architecture-invariant effect

This workunit is documentation-only. In particular it preserves:

- invariant 3, explicit data separation;
- invariant 7, transactional checkpoint/trial/retry/commit/rollback semantics;
- invariant 9, generic `[t0,t1]` time;
- invariant 13, absolute mass conservation;
- invariant 26, runtime diagnostics;
- invariant 30, explicit architecture audit discipline.

All other invariants have zero adverse implementation delta because F-DOC03 changes no production or reference tree.

## Nonclaims

F-DOC03 does not reopen RB1 scientific or canonical authority. It does not alter the F-RB01 capability denominator. It does not qualify coupling, deep-vadose, RossFast or any other excluded capability. It makes no new performance claim. Surface-evaporation call-local copy/allocation throughput and scaling remain a separate performance workunit and are not part of this tranche.
