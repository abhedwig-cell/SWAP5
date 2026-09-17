# P1 publication qualification set

## Purpose

PUB-P1E01 freezes the first evidence map for Paper 1 without inventing missing comparisons. It distinguishes paired legacy/successor preservation evidence from reference-only evidence, successor-only production evidence and architectural probes.

This is a publication-evidence inventory. Existing canonical qualification remains authoritative.

## Inclusion rule

A result may enter the final cross-migration preservation matrix only when its exact authorities, physical comparison, metric and tolerance or identity rule are pinned. Missing values remain missing; a useful legacy test or a successful current test is not automatically a legacy-versus-successor preservation result.

## P1-Q01: corrected-reference shield

**Status:** `REFERENCE_AUTHORITY_QUALIFIED`

The VQ reference chain supplies the immutable audit baseline and corrected numerical/behavioural oracle. It belongs in the methods/provenance argument, but does not by itself prove current SWAP5 whole-run equivalence.

Primary authorities include `docs/verification/vq-1-integration.md`, `docs/verification/reference-baselines.md` and `docs/verification/legacy-differences.md`.

## P1-Q02: restricted Hupsel PMdirect process migration

**Status:** `QUALIFIED_REFERENCE_SUCCESSOR_PROCESS_PAIR`

F-APP03 is currently the strongest explicit paired migration example. Against the exact legacy source oracle it covers 384 daily and 14,062 interval records, including positive-interception paths, with zero mismatches and reported maximum absolute errors of `5.55e-17` daily and `1.11e-16` at interval level.

This supports a restricted process-level behaviour-preservation claim. It is not whole-Hupsel equivalence and must not be generalized to application/runtime composition.

Primary authority: PR #178 and its F-APP03 qualification evidence.

## P1-Q03: transactional state semantics

**Status:** `PARTIAL_CURRENT_PRODUCTION_EVIDENCE`

Historical TX/TIME verifier work remains useful for method history but is not counted as production evidence where it explicitly did not execute production physics.

Current canonical evidence is stronger and more specific:

- F-KT22 executes the real serialized Reference backend and proves that work from a discarded full trial is absent from accepted trajectory publication. It also proves that requesting accepted-trajectory diagnostics does not change the accepted physical candidate or mass accounting in that fixture.
- FMR44R executes the real Reference/HeadCalc production route with prescribed bottom flux. Accepted cases require hard mass closure and `final_revision == 1`, giving direct restricted-route evidence for exactly one external commit.
- The FMR44R positive-qbot case uses a duration of `1.0e-4 day` and commits through production physics, providing direct evidence that the core runtime is not restricted to day-sized steps. Its equilibrium case uses `0.25 day`.
- FVQ75 independently replays the admitted FMR44R capability and rechecks mass residual, positive transfer closure and the temporal certificate.
- FMR44R also proves a nearby unsupported bottom mode fails closed with revision unchanged and no solver execution. That is useful pre-solver rejection evidence, but it is not post-solver rollback evidence.

The machine-readable claim-by-claim classification is in `docs/publication/P1_TRANSACTION_EVIDENCE_MAP.json`.

### Transaction claims already supportable

Within the exact restricted Reference fixtures, Paper 1 can now support:

1. accepted production intervals can commit exactly once;
2. accepted production intervals satisfy the hard mass gate;
3. non-day step durations execute through real production physics;
4. unsupported requests can fail before solver execution without advancing committed revision;
5. discarded trial diagnostic work can be excluded from accepted publication.

### Transaction claims still requiring focused evidence

Paper 1 should not yet claim generally that:

1. a physically executed trial that is subsequently rejected leaves the committed water state exactly unchanged;
2. water transfers from such a rejected physical trial are proven absent from committed totals by a dedicated production fault-injection test;
3. checkpoint -> run -> restore -> rerun is explicitly identical on the selected production publication fixture;
4. changing numerical warm-start state leaves accepted physical output unchanged within a preregistered tolerance.

The old `TX-WARM-01` verifier case is synthetic and therefore does not close the warm-start claim.

## P1-Q04: prescribed-bottom-flux temporal production route

**Status:** `QUALIFIED_SUCCESSOR_ONLY`

FMR44R and FVQ75 supply useful current production evidence for explicit temporal and conservation semantics. FVQ75 independently replays the route and checks hard mass residual, positive transfer closure and a bounded temporal certificate.

This remains successor-only evidence until a matching legacy-side comparison is selected. It therefore cannot populate a legacy-to-successor deviation cell by itself.

Primary current authorities:

- `tests/fmr/test_fmr44r_serialized_prescribed_qbot_runtime.f90`
- `tests/fmr/run_fmr44r_serialized_prescribed_qbot_gate.sh`
- `tests/fvq/run_fvq75_prescribed_qbot_temporal_runtime_independent.sh`

## P1-Q05: RossFast surgical substitution

**Status:** `QUALIFIED_ARCHITECTURAL_PROBE`

F-ROSS12 shows that an alternative soil-water solver can be selected behind the existing solver seam while the surrounding production transaction architecture remains owner. This is useful for Paper 1 only as evidence of architectural separability.

It is `PUB_SHARED_INFRASTRUCTURE` relative to Paper 2. Paper 1 must not use it to claim RossFast accuracy, scientific admissibility, speed or preference.

## P1-Q06: full legacy application trajectory through typed adapters

**Status:** `NOT_YET_FROZEN_FOR_PUBLICATION`

Restricted process preservation does not prove complete file-driven application preservation. A Paper 1 end-to-end case must pin both the exact legacy application authority and the exact current typed application composition, then compare the complete trajectory under a declared rule.

This remains one of the main empirical gaps.

## Frozen evidence set

| ID | Scope | Current publication role |
| --- | --- | --- |
| P1-Q01 | corrected reference shield | methods/provenance |
| P1-Q02 | restricted Hupsel PMdirect | paired process-preservation evidence |
| P1-Q03 | transaction semantics | partial production evidence; focused gaps remain |
| P1-Q04 | prescribed-qbot Reference runtime | successor-only production evidence |
| P1-Q05 | alternative solver substitution | architectural probe/shared infrastructure |
| P1-Q06 | full file-driven application trajectory | open end-to-end preservation gap |

The machine-readable preservation matrix is `docs/publication/p1-preservation-matrix.json`. Unavailable measurements remain `null` or explicitly non-comparable and are never converted to zero.

## Minimum new Paper 1 executions

The evidence inventory now narrows the next empirical work substantially. The minimum targeted additions are:

1. one production post-solver rejection experiment that snapshots committed state and revision before and after rejection and verifies rejected water transfer is absent from committed mass totals;
2. one explicit checkpoint -> run -> restore -> rerun production identity experiment if existing immutable evidence cannot be promoted safely;
3. one production warm-start perturbation experiment;
4. one exact end-to-end legacy-file versus typed-application trajectory comparison for P1-Q06.

These should be separate publication experiments. Production or reference source must not be modified merely to force a complete-looking matrix.
