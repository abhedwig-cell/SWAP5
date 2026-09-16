# F-PE15 — A23au macropore rate-scratch recovery

Date: 2026-09-16

Status: `CLOSED_NO_PRODUCTION_MUTATION_PARENT_AND_SCOPE_BOUNDED`

## Scope

This bounded workunit evaluates the recovered A23au macropore rate-scratch optimization as additional late-August / early-September SWAP performance evidence.

Protocol:

`RECONCILE -> CLASSIFY -> MAP -> QUALIFY_RECOVERED_EVIDENCE -> CLOSE`

No new implementation is performed unless exact parent/source authority and current-target applicability both close.

Explicit exclusions:

- no Energy Balance work;
- no RossFast work;
- no new macropore physics;
- no transaction or mass-policy change;
- no claim that memory reduction equals wall-time speedup;
- no claim of whole-macropore thread safety;
- no reconstruction of missing cumulative A23 source from reports.

## Current authorities

SWAP5:

- canonical branch: `integration/f-ci-canonical`
- canonical commit: `80c6faaa8a277d9596a6da7bc5d2244c0df1bb82`
- canonical tree: `9b3ee78c9ff5dfde12345ef4e472e74d41ac0da3`
- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`

Historical exact child artifact recovered from the File Library:

`A23AT_to_A23AU.patch`

Historical qualification authorities recovered:

- `A23AU_REPORT.md`;
- `A23AU_MACROPORE_RATE_SCRATCH_CONTRACT.md`.

## What A23au changes

A23au removes five hidden cross-call `SAVE` arrays from `SATFLOW` and `ABSORPTION` and gives them explicit execution ownership through a `MacroporeRateScratchA23` object.

The exact recovered child patch touches:

```text
headcalc.f90
macropore.f90
macrorate.f90
new mod_a23_macropore_rate_scratch.f90
```

The scratch object owns active-sized arrays for head differences, matrix-flow workspace, diffusivity and sorptivity flags. No macropore physical continuation-state layout is changed.

This is an ownership/memory optimization, not a change to scientific equations.

## Historical qualification

The recovered evidence is substantial and internally coherent.

### Numerical / functional preservation

Official two-day Andelst macropore case:

- focused A23at-equivalent parent PASS;
- A23au child PASS;
- normalized `result_output.csv` identical;
- normalized `soilshrinkchar.csv` identical;
- stable numeric rows of `macrogeom.csv` identical;
- the `result_output.csv` hash matches the retained formal A23at reference.

Retry/rollback case:

- `DTMAX=0.02`, `MAXIT=8`;
- exactly one real `MacroStateVar(2)` rollback in both parent and child;
- parent and child `result_output.csv` hashes identical;
- result matches the retained formal A23at retry hash.

This supports the intended semantic classification of the extracted arrays as execution scratch rather than committed physical state.

### Reentrancy of the extracted scratch

The scratch module was qualified under `-frecursive -fcheck=all -fopenmp` with:

```text
workers       8
reuse checks  16,000
failures      0
```

This establishes reentrancy of the extracted scratch object only. It does not establish thread safety of the complete legacy macropore implementation.

### Memory result

Legacy fixed helper payload at compile-time maxima `MaDm=20`, `MaCp=5000`:

```text
SATFLOW       840,000 B
ABSORPTION  1,240,000 B
total       2,080,000 B
```

A23au qualification case `NumDm=5`, `NumNod=112`:

```text
12,992 B
```

Recorded reduction:

```text
160.10x smaller
99.375% payload reduction
```

A 2-domain x 34-node scratch object requires 1,904 B.

These are helper-workspace memory measurements, not runtime speed measurements.

The approximately 1.94 MB top-level `MACRORATE` workspace identified by A23at remains outside A23au and was not optimized by this candidate.

## Historical parent provenance

A23au is better preserved than several other recovered candidates because the exact `A23AT_to_A23AU.patch` is available.

The original A23au qualification reports that the exact A23at versions of every pre-existing file touched by A23au were reconstructed from supplied SWAP source plus retained A23as/A23at patch lineage, and that:

```text
reconstructed focused A23at parent  65 source units PASS
A23au child                         66 source units PASS
patch-applied A23au                 66 source units PASS
patched touched-source identity     PASS
```

However the same report explicitly states that the **full cumulative A23at source tree was unavailable** during that recovery. The retained historical A23at report described 111 cumulative source units, so a new 111-unit cumulative A23at+A23au rebuild was not claimed.

F-PE15 searched directly for standalone `A23AR_to_A23AS.patch` and `A23AS_to_A23AT.patch` artifacts. Those files were not recovered from the currently searchable File Library surface. The exact A23au child patch is present, but the full parent lineage is not independently available here as a complete artifact chain.

## Diagnostic limitation inherited from historical qualification

A reconstructed full-model `-fcheck=all` run hit an independent pre-existing macropore index-0 error involving `qexcmtxdmcp` in the `MacroState` path in both parent and child.

Therefore A23au never established a fresh whole-model recursive/bounds-clean qualification. Its reentrancy claim is deliberately limited to the extracted scratch module, while normal and rollback numerical equivalence are established by end-to-end production builds.

This limitation does not invalidate the bounded scratch result, but it prevents widening the qualification claim.

## Classification

Historical A23at -> A23au candidate:

`B — EXACT_SEMANTICS_PRESERVING_PERFORMANCE OPTIMIZATION, LOCALLY QUALIFIED`

The performance dimension here is primarily memory/ownership scalability. No wall-time speedup is claimed.

## Target A — SWAP 4.3.1 stable legacy line

Disposition:

`D — STRONGLY QUALIFIED LOCAL CANDIDATE, DIRECT STABLE-LINE ADMISSION NOT CLOSED`

Reason:

- exact child patch exists;
- exact touched-parent reconstruction was qualified historically;
- functional, rollback, scratch-reentrancy and memory gates are strong;
- but the complete cumulative A23at parent postimage is not available in the present recovery surface;
- the full 111-unit cumulative build was explicitly not reproduced in the original A23au recovery;
- F-PE15 must not silently replace cumulative lineage proof with a focused touched-file reconstruction.

No legacy source mutation is made.

## Target B — current SWAP5

The current typed production route explicitly rejects active macropores:

```fortran
if (swmacro /= 0) return
```

and binds the admitted typed request with `macropore_active = .false.`.

Therefore A23au is not an optimization for the current admitted typed Full Richards profile.

A legacy compatibility route still exists behind the common solver seam for unsupported configurations, so the macropore concept is not declared globally obsolete. However the current committed SWAP5 source tree does not expose A23au's `macrorate.f90` ownership surface as an admitted typed macropore production capability, and Status-A does not authorize speculative performance work on non-admitted execution modes.

Target-B disposition:

`D — PROMISING PRIOR EXACT-SEMANTICS EVIDENCE, DEFERRED OUTSIDE CURRENT ADMITTED TYPED MACROPORE PROFILE`

This is intentionally not class E: the optimization is not technically obsolete. It is simply not qualified against a current admitted macropore production surface.

## IMPLEMENT decision

```text
TARGET_A = NO_MUTATION_COMPLETE_PARENT_ADMISSION_SURFACE_NOT_CLOSED
TARGET_B = NO_MUTATION_MACROPORE_TYPED_PROFILE_NOT_ADMITTED
```

No source is changed in F-PE15.

## Current value of the recovered candidate

A23au remains useful prior evidence for a future SWAP5 macropore migration because it already demonstrates three architecture properties that align with current SWAP5 rules:

- helper arrays can be explicit worker/job scratch instead of hidden `SAVE` state;
- scratch need not participate in rollback/checkpoint state;
- active-sized scratch can cut compile-time-max helper memory by orders of magnitude without changing qualified outputs.

Those lessons may inform a future macropore capability, but the historical patch must not be mechanically ported into current SWAP5.

## Next highest-value recovered performance target

Within the still-unclosed historical performance evidence, the next technically attractive target is the **A23at top-level MACRORATE workspace** noted by the A23au report: approximately 1.94 MB of max-sized temporary workspace remained outside A23au.

This is only a candidate lead. Before any implementation, its own A23at evidence, exact ownership/lifetime and current SWAP5 applicability must be recovered and classified. No speed or memory reduction is claimed for that next cut yet.

## Closeout

```text
F-PE15 = CLOSED_NO_PRODUCTION_MUTATION_PARENT_AND_SCOPE_BOUNDED
HISTORICAL_CLASS = B_LOCAL_EXACT_MEMORY_PERFORMANCE_OPTIMIZATION
TARGET_A = D_DIRECT_ADMISSION_NOT_CLOSED
TARGET_B = D_DEFERRED_OUTSIDE_CURRENT_ADMITTED_TYPED_MACROPORE_PROFILE
PRODUCTION_SOURCE_CHANGE = NONE
LEGACY_SOURCE_CHANGE = NONE
WALL_TIME_SPEEDUP_CLAIM = NONE
```

Reopen only if either:

1. the complete authoritative A23at parent postimage / patch lineage becomes available for direct legacy admission qualification; or
2. SWAP5 admits an explicit macropore typed-production capability and nominates this scratch ownership problem as a current performance surface.
