# F-PE16 — S12 macropore memory-performance recovery

Date: 2026-09-16

Status: `CLOSED_NO_PRODUCTION_MUTATION_RECOVERED_SCOPE_BOUNDED`

## Scope

This bounded workunit recovers and classifies the earlier S12 macropore memory/ownership line discovered while closing the late-August / early-September SWAP performance inventory.

Primary recovered candidates:

- S12o active-sized committed `MacroporeColumnState`;
- S12r active-sized `MacroporeRateScratch`.

Protocol:

`RECONCILE -> CLASSIFY -> MAP -> CLOSE`

This is not a license to reconstruct missing parent source or to combine historical patches into a new production postimage.

Explicit exclusions:

- no Energy Balance work;
- no RossFast work;
- no new macropore physics;
- no transaction or mass-policy change;
- no mechanical port into SWAP5;
- no wall-time speedup claim where only memory was measured;
- no mixing of correctness fixes with performance credit.

## Authorities

SWAP5:

- canonical branch: `integration/f-ci-canonical`;
- live canonical commit at start: `80c6faaa8a277d9596a6da7bc5d2244c0df1bb82`;
- canonical tree: `9b3ee78c9ff5dfde12345ef4e472e74d41ac0da3`;
- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`;
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`.

Recovered File Library authorities include:

- exact `S12o_macropore_column_state.patch`;
- exact `S12o_corrected_fixed_reference_macropore.patch`;
- `S12o_test_summary.txt`;
- `S12o_full_season_equivalence.txt`;
- `S12o_requalification_repeat.txt`;
- `S12o_qualification_results.json`;
- `S12o_dependency_map.txt`;
- exact `S12r_delta_after_S12q.patch`;
- `S12r_architecture_note.txt`.

## Mandatory correctness/performance separation

S12o exposed four legacy undefined-behaviour/correctness defects while changing macropore storage layout.

The four corrections are:

1. define `icgwl` from `ICpTpWaSrDm(id)` in the standard-flow `MACROSTATE` branch;
2. guard saturated reconstruction when `ICpBtDm(id) < 1` and prevent compartment-0 iteration;
3. make the `VlMpDm1Cp(1:numnod)` assignment shape-explicit;
4. initialize `SorpFac = 1.0` before optional Darcy exchange in `ABSORPTION`.

An exact separate patch exists for these corrections:

`S12o_corrected_fixed_reference_macropore.patch`.

They are therefore classified independently as:

`A — CORRECTNESS_FIX / UB_REPAIR SET`.

They must not be counted as the S12o memory optimization.

The exact `S12o_macropore_column_state.patch` is a compound end-state patch: it contains the active-sized state migration and the same correctness repairs. The performance/layout claim is qualified relative to the corrected fixed-array reference, not relative to the uncorrected source.

## S12o active-sized committed macropore state

### What changes

S12o moves seven committed physical/history fields from fixed `MaDm`/`MaCp` module arrays into an allocatable `MacroporeColumnState` sized to active `NumDm` and `NumNod`:

```text
ICpBtDm
SorpDmCp
ThtSrpRefDmCp
TimAbsCumDmCp
VlMpDmCp
WaUnMpDmCp
VlMpDyCp
```

Legacy pointer views continue to feed the existing physics. Ordinary derived-type assignment of the allocatable state provides deep-copy semantics.

Correct lifecycle recovered by the qualification is:

```text
MACROGEOM -> NumDm known -> allocate active state -> bind legacy views -> initialize state
```

This is primarily a memory/ownership optimization and architecture migration. It does not introduce new physical equations.

### Numerical qualification

The final allocatable implementation was qualified against a fixed-array reference carrying the same four correctness repairs.

Recovered evidence includes:

- complete Andelst available period 1997-12-31 through 1999-04-26;
- 489 output rows;
- all numerical `result_output.csv` lines identical;
- `swap.wrn` byte-identical;
- `swap.bbc` byte-identical;
- `macrogeom.csv` numeric tail identical;
- `soilshrinkchar.csv` numeric tail identical;
- repeated clean-room rebuild and rerun reproduced byte-identical `result_output.csv`, `swap.wrn` and `swap.bbc` between corrected fixed reference and final dynamic candidate;
- Grassgrowth: 1835 rows, no numerical differences;
- SWKIMPL=1: 1835 rows, no numerical differences;
- SWDROUGHT=2 and 3: 44 rows each, no numerical differences;
- `-O0 -g -fcheck=all -fbacktrace` Andelst 10-day gate completed normally;
- direct state probe verified deep copy, same-shape preservation, resize-clear and release-to-zero.

This is sufficient to classify the **layout change itself**, against the corrected reference used in the test, as exact-semantics within the qualified scope.

### Memory qualification

Repeated measurement records:

```text
corrected fixed macropore.o   12,965,264 B
final dynamic macropore.o      8,965,744 B
reduction                      3,999,520 B

corrected fixed variables.o    5,761,252 B
final dynamic variables.o      5,721,316 B
state module BSS                     568 B
combined net static reduction  4,038,888 B
```

The same 3,999,520 B `macropore.o` reduction remains under `-fno-automatic`.

Active state payload examples:

```text
NumDm=5, NumNod=112     23,316 B
plus accepted history   27,796 B
NumDm=2, NumNod=100      8,808 B
plus accepted history   10,408 B
```

These are memory results. No S12o whole-model wall-time speedup is claimed.

### Remaining S12o limitations

The qualification itself records that:

- `legacy_macropore_column_state` is still a singleton;
- legacy pointer views remain module-global and MACROPORE is not reentrant;
- checkpoint/reference arrays remain fixed-size globals;
- `SorpDmCp` and `ThtSrpRefDmCp` are trial-mutable while the then-current rollback slice does not restore all such fields;
- substantial trial/result/reporting BSS and SAVE-sensitive locals remain.

Therefore S12o is not a complete MultiSWAP or transaction solution.

### Historical classification

The S12o result must be represented as two coupled but distinct decisions:

```text
S12O_CORRECTED_REFERENCE_UB_SET = A — CORRECTNESS_FIX
S12O_ACTIVE_SIZED_STATE_LAYOUT = B — EXACT_SEMANTICS_PRESERVING_MEMORY/PERFORMANCE_OPTIMIZATION, QUALIFIED_AGAINST_CORRECTED_REFERENCE
```

The B classification does not convert the compound historical end-state patch into a pure performance patch against uncorrected SWAP 4.3.1.

## S12r active-sized rate scratch

### What changes

The exact `S12r_delta_after_S12q.patch` is broader than the later A23au helper-scratch extraction.

It introduces an active-sized `MacroporeRateScratch` covering top-level `MACRORATE` rate workspace plus `SATFLOW`, `ABSORPTION` and `RAPIDDRAIN` helper workspace, including:

- domain-sized integer and real rate arrays;
- node-sized rate, mass-balance and rapid-drain arrays;
- domain x node rate arrays;
- saturated-flow and absorption helper arrays.

The patch threads scratch explicitly through `headcalc -> MACROPORE -> MACRORATE` and related helpers. The standalone wrapper creates an automatic scratch object per invocation; the architecture note recommends future reuse per worker/job.

The recovered architecture note classifies this storage as disposable numerical worker scratch, outside persistent state and rollback/checkpoint state.

### Qualification status

F-PE16 deliberately does **not** inherit S12o or A23au runtime results into S12r.

Direct searches for S12r-specific:

- test summary;
- gate result;
- output hashes;
- rollback result;
- memory result;
- full-season or Andelst equivalence;

recovered only the exact patch and architecture note, not a standalone executable qualification record.

Likewise a searchable exact S12q parent patch/postimage was not recovered in the bounded searches.

Therefore S12r is classified:

`D — PROMISING_BUT_INSUFFICIENTLY_QUALIFIED`.

This is stronger than a speculative idea because the source delta is exact and the ownership design is concrete, but it is not B without matching executable evidence and parent authority.

## Relationship to later A23au/A23av direction

S12r appears to cover a broader active-sized rate workspace than A23au, which deliberately moved only the final five hidden `SATFLOW`/`ABSORPTION` SAVE arrays and left approximately 1.94 MB of top-level `MACRORATE` workspace for a later cut.

That architectural similarity is informative but is not proof that S12r and a hypothetical A23au+A23av postimage are identical. No later candidate may inherit S12r qualification that was not recovered, and no S12r claim may inherit A23au qualification merely because fields overlap.

## Target A — stable SWAP 4.3.1

### S12o

Disposition:

`D — LOCALLY_STRONG, DIRECT_STABLE_LINE_ADMISSION_NOT_CLOSED`.

Reasons:

- exact end-state patch exists;
- exact separate four-fix corrected-reference patch exists;
- strong clean-room numerical and memory qualification exists;
- however the qualified B claim is relative to an S12n corrected reference, not the authoritative unmodified SWAP 4.3.1 source;
- the compound S12o patch mixes the A repair set and B layout migration;
- the exact S12n parent lineage and an independently preserved pure B-only patch were not recovered here;
- F-PE16 must not derive a replacement historical patch and call it the original performance artifact.

A future direct legacy admission would need to establish the correctness repairs as their own accepted prerequisites, then independently derive or recover and qualify the layout-only delta against that accepted postimage.

### S12r

Disposition:

`D — EXACT_DESIGN_PATCH_RECOVERED, QUALIFICATION_AND_PARENT_INSUFFICIENT`.

No legacy source mutation is permitted for either S12o or S12r in F-PE16.

## Target B — current SWAP5

The current Status-A typed soil-water route explicitly sets:

```fortran
request%physical%macropore_active = .false.
```

and `production_route_admitted()` returns without entering that typed route when:

```fortran
swmacro /= 0
```

Thus current admitted typed production does not contain a macropore state/rate surface to which S12o or S12r can be directly ported as a current performance optimization.

The existence of compatibility/future macropore routes means these concepts should not be called technically obsolete. Their current target-B disposition is:

```text
S12O = D — PRIOR EXACT-SEMANTICS MEMORY EVIDENCE, DEFERRED OUTSIDE CURRENT ADMITTED TYPED MACROPORE PROFILE
S12R = D — PROMISING PRIOR DESIGN, DEFERRED AND INSUFFICIENTLY QUALIFIED
```

No current SWAP5 production source mutation is justified.

## IMPLEMENT decision

```text
TARGET_A_S12O = NO_MUTATION_CORRECTNESS_PREREQUISITES_AND_PURE_B_DELTA_NOT_ADMITTED
TARGET_A_S12R = NO_MUTATION_PARENT_AND_EXECUTABLE_QUALIFICATION_MISSING
TARGET_B_S12O = NO_MUTATION_MACROPORE_TYPED_PROFILE_NOT_ADMITTED
TARGET_B_S12R = NO_MUTATION_MACROPORE_TYPED_PROFILE_NOT_ADMITTED
```

## Recovered value for future work

S12o contributes high-quality evidence that active-sized macropore physical/history state can reduce static memory by about 4.04 MB in the tested build while preserving qualified outputs relative to a corrected fixed-array reference.

S12r contributes an exact source design for active-sized worker/job rate scratch that appears to cover the top-level workspace later left open by A23au.

For a future SWAP5 macropore capability, these should be treated as prior design and qualification evidence, not mechanically ported patches. Current SWAP5 state ownership, rollback and worker contracts must remain authoritative.

## Closeout

```text
F-PE16 = CLOSED_NO_PRODUCTION_MUTATION_RECOVERED_SCOPE_BOUNDED
S12O_CORRECTNESS_SET = A
S12O_LAYOUT = B_LOCAL_QUALIFIED_AGAINST_CORRECTED_REFERENCE
S12O_TARGET_A = D_DIRECT_ADMISSION_NOT_CLOSED
S12O_TARGET_B = D_DEFERRED_OUTSIDE_CURRENT_TYPED_MACROPORE_PROFILE
S12R_HISTORICAL = D_INSUFFICIENT_EXECUTABLE_QUALIFICATION
S12R_TARGET_A = D
S12R_TARGET_B = D
PRODUCTION_SOURCE_CHANGE = NONE
LEGACY_SOURCE_CHANGE = NONE
WALL_TIME_SPEEDUP_CLAIM = NONE
```

Reopen only when a concrete missing authority appears: accepted legacy correctness prerequisites plus a pure layout delta, exact S12q parent and S12r runtime qualification, or an admitted SWAP5 macropore typed-production capability.
