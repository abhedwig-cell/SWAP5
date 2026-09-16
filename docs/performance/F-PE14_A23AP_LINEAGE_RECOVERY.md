# F-PE14 — A23ap lineage and rebase recovery

Date: 2026-09-16

Status: `CLOSED_LINEAGE_ARTIFACT_BLOCKED`

## Scope

This bounded workunit follows the F-PE12 performance recovery and F-PE13 SWAP-011 provenance closeout. It addresses one remaining historical exact-semantics performance candidate only:

**A23ap root-extraction oxygen-reproduction cumulative-prefix transformation.**

Protocol:

`RECONCILE -> RECOVER -> VERIFY -> CLOSE`

This is a recovery/rebase-admission assessment. It is not permission to reconstruct missing A23 lineage patches from technical reports.

Explicit exclusions:

- no Energy Balance work;
- no RossFast work;
- no SWAP5 production mutation;
- no oxygen-physics change;
- no reconstruction of missing A23 intermediate source from prose;
- no claim of a 6.65x root-extraction or whole-SWAP speedup;
- no stable-legacy admission without a complete verifiable parent lineage.

## Authorities

SWAP5 current canonical at start:

- branch: `integration/f-ci-canonical`
- commit: `80c6faaa8a277d9596a6da7bc5d2244c0df1bb82`
- tree: `9b3ee78c9ff5dfde12345ef4e472e74d41ac0da3`
- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`

Historical A23ap authority is the recovered A23ap technical report and oxygen-reproduction contract. The report status is:

`A23AP_STATUS = PASS_ROOTEXTRACTION_CURRENT_SATURATION_AND_LINEAR_PREFIX_OXYGEN_REPRO_FORMAL_A23Y_FACADE_REBASE_OPEN`

## Historical A23ap qualification

A23ap is a real exact-semantics local performance candidate, not a speculative optimization.

The bounded transformation replaces repeated reconstruction of the porosity prefix in `OxygenReproFunction` with one cumulative prefix maintained in root extraction while retaining the same node-order addition sequence.

Recovered qualification establishes:

- frozen-reference evaluations: 100,000;
- bitwise mismatches: 0;
- controlled oxygen-reproduction calls: 16,116;
- macro calls: 3,788;
- microscopic calls: 12,328;
- current saturation requests: 194,924;
- stale saturation requests/calls: 0;
- A23ao/A23ap controlled BAL/BLC byte identity;
- standard Stock/Ruurlo and Hupsel normalized output preservation;
- diagnostic and production-like cumulative 112-source-unit builds PASS;
- fresh-parent A23ao -> A23ap patch-application qualification PASS according to the retained report;
- no new persistent physical state, profile arrays, shared payload or profile worker scratch.

The operation-count evidence is:

```text
legacy repeated prefix terms   1,295,437
A23ap cumulative prefix terms    194,924
reduction                         84.95%
legacy/new addition ratio          6.65x
```

This is an operation-count reduction for the prefix only. It is not measured wall-time acceleration of root extraction or SWAP.

## Classification

Historical local lineage:

`B — EXACT_SEMANTICS_PRESERVING_PERFORMANCE_OPTIMIZATION, LOCALLY_QUALIFIED`

This classification is retained from F-PE12.

A23ap must not be reclassified as a correctness repair. Its report explicitly notes that `SWTILL=1` with `SWOXYGEN=2` is rejected, so the stale-saturation tillage mechanism from adjacent A23 work is not a reachable valid runtime route for this A23ap oxygen-reproduction scope.

## Exact lineage recovery

F-PE14 searched the File Library explicitly for the intermediate patch chain from A23y through A23ap, including grouped exact names such as:

```text
A23Y_to_A23Z.patch
A23Z_to_A23AA.patch
A23AA_to_A23AB.patch
A23AB_to_A23AC.patch
...
A23AN_to_A23AO.patch
A23AO_to_A23AP.patch
```

The searches did not recover a complete exact patch chain.

Exact artifacts that were recovered elsewhere in the A23 family include:

- `A23X_to_A23Y.patch`;
- `A23Y_NONINTERFERENCE.json`;
- later unrelated `A23AT_to_A23AU.patch`;
- multiple intermediate/final technical reports.

The exact `A23AO_to_A23AP.patch` itself was not returned as a File Library artifact in the bounded searches, even though the A23ap report records that such a parent/child patch was applied successfully to a fresh A23ao tree during its original qualification.

More importantly, the retained A23ap report itself keeps the **formal cumulative rebase onto the original A23y production facade open**. Earlier intermediate A23 reports likewise record incomplete or unavailable cumulative facade/source-tree reconstruction at several points.

Therefore the missing admission surface is not safely reducible to one guessed child patch. The authoritative target requires a complete verifiable lineage/rebase, not an equivalent source tree reconstructed from report descriptions.

## Target A disposition

For SWAP 4.3.1 stable legacy maintenance:

`D — PROMISING/LOCALLY_QUALIFIED BUT INSUFFICIENTLY QUALIFIED FOR DIRECT STABLE-LINE ADMISSION`

Reason:

- local A23ao -> A23ap equivalence evidence is strong;
- exact local performance semantics are qualified;
- however the full cumulative production-facade lineage from the authoritative legacy target to the qualified A23ap postimage is not recoverable as an exact artifact chain;
- the original report explicitly left that formal rebase open.

No Target-A source mutation is permitted in F-PE14.

## Target B disposition

Current SWAP5 Status-A root-water-uptake production is bounded to the admitted Feddes drought process and has no admitted `OxygenReproFunction` / `SWOXYGENTYPE=2` reproduction route on that production owner.

Therefore:

`E — NOT APPLICABLE TO CURRENT ADMITTED SWAP5 ROOT-UPTAKE PRODUCTION PATH`

This is target-specific. It does not mean the cumulative-prefix technique is technically obsolete. If an oxygen-reproduction capability is later admitted into SWAP5, A23ap can be reconsidered as prior exact-semantics design/evidence, but it must then be implemented under current ownership and independently qualified.

## IMPLEMENT decision

```text
TARGET_A = NO_MUTATION_CUMULATIVE_LINEAGE_REBASE_OPEN
TARGET_B = NO_MUTATION_CURRENT_PATH_NOT_APPLICABLE
```

F-PE14 does not reconstruct missing source, does not create an A23ap substitute patch and does not broaden current SWAP5 oxygen capabilities.

## Closeout

Protocol result:

```text
RECONCILE = COMPLETE
RECOVER   = COMPLETE_WITH_INCOMPLETE_EXACT_LINEAGE
VERIFY    = LOCAL_A23AP_EVIDENCE_VALID; DIRECT_TARGET_A_REBASE_NOT_ESTABLISHED
CLOSE     = LINEAGE_ARTIFACT_BLOCKED
```

Final verdict:

```text
F-PE14 = CLOSED_LINEAGE_ARTIFACT_BLOCKED
HISTORICAL_A23AP_CLASS = B_LOCAL_EXACT_PERFORMANCE_OPTIMIZATION
TARGET_A_DIRECT_ADMISSION = D_BLOCKED_BY_CUMULATIVE_REBASE
TARGET_B_CURRENT_APPLICABILITY = E_NOT_APPLICABLE
PRODUCTION_SOURCE_CHANGE = NONE
LEGACY_SOURCE_CHANGE = NONE
NEW_SPEEDUP_CLAIM = NONE
```

## Reopen gate

Reopen only if a new artifact source supplies either:

1. the exact cumulative A23y-through-A23ap production-facade source/postimage with verifiable provenance; or
2. a complete exact intermediate patch sequence sufficient to reproduce that postimage from the authoritative A23y parent and rerun the qualification.

Do not restart F-PE14 merely to repeat filename searches or recreate missing intermediate patches from technical reports.
