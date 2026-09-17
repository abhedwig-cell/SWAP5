# P1 publication qualification set

## Purpose

PUB-P1E01 freezes the first evidence map for Paper 1 without inventing missing comparisons. The goal is to distinguish evidence that already compares a qualified scientific reference with a migrated successor from evidence that proves only one side of that comparison.

This is a publication-evidence inventory, not a new scientific qualification layer. Existing canonical qualification remains authoritative.

## Inclusion rule

A case may enter the final cross-migration preservation matrix only when all of the following are pinned:

1. exact reference authority;
2. exact successor authority;
3. same physical question or a documented transformation between representations;
4. machine-readable comparison metric;
5. declared tolerance or exact-identity rule;
6. no unresolved expected-difference classification that would invalidate the comparison.

A useful legacy case is not automatically a publication preservation case. Likewise, a successful current SWAP5 test is not automatically a legacy-equivalence result.

## Evidence classes

### P1-Q01: corrected-reference identity and control edges

**Role:** reference shield evidence.

**Current status:** `REFERENCE_AUTHORITY_QUALIFIED`.

The VQ reference chain establishes an immutable audit baseline and a corrected numerical/behavioural oracle. Broad control edges include the official grass-growth trajectory and Hupsel balance outputs, with explicit caveats about compiler/runtime portability and rounded legacy balance precision.

**Use in Paper 1:** methods and provenance of the executable reference shield.

**Not sufficient for:** claiming that current SWAP5 reproduces these full trajectories. A current successor comparison must be pinned separately.

Primary authorities:

- `docs/verification/vq-1-integration.md`
- `docs/verification/reference-baselines.md`
- `docs/verification/legacy-differences.md`

### P1-Q02: restricted Hupsel SWETR=0 PMdirect process migration

**Role:** process-level behaviour-preserving migration evidence.

**Current status:** `QUALIFIED_REFERENCE_SUCCESSOR_PROCESS_PAIR`.

F-APP03 qualified one restricted PMdirect process route against the exact legacy source oracle. Its reported comparison covers 384 daily and 14,062 interval records, including positive-interception routes, with zero mismatches and errors at floating-point roundoff scale.

This is valid evidence that one scientific process family was extracted into a typed process without changing the qualified process behaviour.

**Boundary:** this is not whole-Hupsel equivalence and must not be presented as such. Runtime/application composition belongs to later F-APP work.

Primary authority:

- PR #178 and `integration/f-app/F-APP03_RESTRICTED_PMDIRECT_PROCESS_QUALIFICATION.json` when present on the admitted lineage.

### P1-Q03: transactional state semantics

**Role:** test H2, committed physical state is distinct from rejected trial history.

**Current status:** `PARTIAL_CURRENT_PRODUCTION_EVIDENCE`.

Canonical verification terminology defines rollback, commit, accounting, rerun, boundary replay, warm-start and generic-time cases. Historical VQ work also records the important distinction between synthetic verifier-harness evidence and production-physics qualification.

There is now a stronger current production anchor. The canonical F-KT22 serialized runtime gate executes the real Reference production backend under a full-versus-two-half temporal path. It explicitly checks that work performed for the discarded full trial remains diagnostic-only and is absent from accepted-route publication. It also snapshots the two accepted physical candidates and requires their physical state and mass accounting to remain bit-identical when accepted-trajectory diagnostics are enabled versus disabled. The F-ROSS12 current-canonical qualification replayed this F-KT22 production runtime gate successfully after the alternative-solver dependency graph was present.

This is publication-relevant production evidence for two points:

1. rejected trial work can exist without contaminating the published accepted trajectory;
2. adding accepted-route diagnostic/tangent work does not alter the accepted physical candidate or mass accounting in that fixture.

It is **not yet the entire six-property transaction proof** required by Paper 1.

Current publication rule:

- synthetic or harness-only TX/TIME evidence may document method development;
- current F-KT22 production evidence may support rejected-trial isolation and physical-identity claims within its exact fixture;
- each remaining Paper 1 TX/TIME property must be rebound to an exact current production route and immutable qualification artifact before being claimed generally.

Evidence still to pin or add:

- rejected terminal/retry trial leaves the committed physical state itself unchanged, not only accepted-route publication;
- accepted endpoint commits exactly once;
- rejected-trial water accounting never enters committed totals across a real retry path;
- same committed state replays consistently through a real retry path;
- warm-start variation does not alter accepted physical result outside tolerance;
- selected non-day/non-midnight interval evidence on current production physics.

Primary current authorities:

- `tests/fkt/run_fkt22_fmr_runtime_gate.sh`
- `tests/fkt/test_fkt22_fmr_serialized_trajectory_runtime.f90`
- `integration/f-ross/F-ROSS12_STATUS.json` for the later current-canonical replay context.

### P1-Q04: prescribed-bottom-flux temporal runtime qualification

**Role:** current production evidence for explicit temporal/conservation semantics.

**Current status:** `QUALIFIED_SUCCESSOR_ONLY`.

FVQ75 independently replays the prescribed-qbot production route and checks, among other things, mass residual, positive transfer closure and a bounded temporal certificate. This is useful successor evidence that generic transaction/runtime properties exist in real production code.

**Boundary:** FVQ75 is not itself a legacy-versus-successor comparison and therefore cannot populate a cross-migration deviation cell without a matching reference-side experiment.

Primary authority:

- `tests/fvq/run_fvq75_prescribed_qbot_temporal_runtime_independent.sh` and its admitted qualification lineage.

### P1-Q05: RossFast surgical substitution

**Role:** architectural consequence, not scientific solver-comparison result.

**Current status:** `QUALIFIED_ARCHITECTURAL_PROBE`.

F-ROSS12 proves that an alternative soil-water solver can execute through the existing production transaction lifecycle and solver seam without changing the transaction ABI, legacy input grammar or Reference physics. Unsupported conditions fail before commit and there is no silent fallback to Reference.

**Use in Paper 1:** evidence for architectural separability, H3.

**Publication class:** `PUB_SHARED_INFRASTRUCTURE` with respect to Paper 2.

**Forbidden P1 inference:** no statement about RossFast scientific equivalence, speed, admissibility domain or preferred use.

Primary authority:

- `integration/f-ross/F-ROSS12_STATUS.json`

### P1-Q06: full legacy application trajectory through current typed adapters

**Role:** end-to-end evidence for the claim that substantial structural migration preserves a complete file-driven scientific run.

**Current status:** `NOT_YET_FROZEN_FOR_PUBLICATION`.

At the PUB-P1E01 checkpoint, restricted process-level Hupsel evidence exists, but the publication register must not infer whole-Hupsel equivalence from that. A candidate end-to-end case may enter only after the exact current application-composition authority and its reference comparison are admitted and pinned.

This is an important gap because process-level exactness alone does not demonstrate preservation across the complete migrated application boundary.

## Provisional matrix structure

The publication matrix will use the following columns:

```text
case_id
scientific_scope
reference_authority
successor_authority
comparison_level
state_metric
state_result
integrated_top_flux_metric
integrated_top_flux_result
integrated_bottom_flux_metric
integrated_bottom_flux_result
mass_metric
mass_result
expected_difference_class
tolerance_or_identity_rule
verdict
limitations
publication_role
```

Missing measurements remain null or `NOT_COMPARABLE`. They must never be converted to zero.

## First frozen set

| ID | Scope | Reference | Successor | Current publication status |
| --- | --- | --- | --- | --- |
| P1-Q01 | corrected reference shield | qualified | n/a | methods/provenance only |
| P1-Q02 | restricted Hupsel PMdirect process | exact legacy oracle | typed process | qualified paired process evidence |
| P1-Q03 | transaction semantics | semantic contract | current F-KT22 proves part of the production semantics | partial production evidence, targeted closure remains |
| P1-Q04 | prescribed-qbot temporal runtime | no paired legacy result yet | qualified current route | successor-only evidence |
| P1-Q05 | solver substitution architecture | Reference lifecycle | RossFast through same lifecycle | architectural probe only |
| P1-Q06 | full legacy application trajectory | candidate legacy case | current typed application path | not yet frozen |

## Why this set is intentionally uneven

A publication qualification set should reflect what is actually proven, not create symmetry by assumption. P1-Q01 and P1-Q04 therefore remain one-sided evidence classes. P1-Q02 is currently the strongest explicit paired scientific migration result. P1-Q03 now has real current production evidence, but only for a subset of the intended transaction claims. P1-Q06 remains open rather than borrowing a process-level result to make an end-to-end claim.

## Next permitted P1E01 actions

1. classify the remaining transaction properties as production-proven, harness-only or missing, using current canonical evidence only;
2. locate the latest admitted application-composition evidence relevant to P1-Q06;
3. update the machine-readable matrix without converting absent comparisons into synthetic values;
4. only after those steps decide the minimum new executions needed for publication.

No production or reference source change is permitted within PUB-P1E01 merely to make the matrix look complete.
