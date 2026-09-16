# F-PE12 — OxygenStress-adjacent performance recovery

Date: 2026-09-16

This record reconciles two later historical OxygenStress-adjacent lines that were recovered after the first F-PE12 classification pass.

They are kept separate from the two earlier runtime experiments already recorded in the main checkpoint:

- duplicate-QROMBD removal;
- fast no-stress exit.

The later S9 and A23ap evidence must not be used to retroactively qualify those earlier experiments. The older two remain class D unless their own isolated postimages and qualification evidence are recovered.

## Current SWAP5 target scope

Current target-B authority for this mapping:

- canonical branch: `integration/f-ci-canonical`
- live canonical commit: `80c6faaa8a277d9596a6da7bc5d2244c0df1bb82`
- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`

The current production owner `src/process/mod_root_water_uptake_process.f90` exposes only:

```text
evaluate_macro_feddes_drought_uptake
```

Its inputs, outputs and diagnostics are pressure-head/Feddes drought semantics. The complete source contains no OxygenStress precomputation, no `OxygenReproFunction`, no Bartholomeus oxygen model, no `SWOXYGEN` option handling and no oxygen reproduction prefix algebra.

A recursive canonical-tree path check also found no production path named for `oxygenstress`, `OxygenReproFunction` or legacy `rootextraction.f90`.

This is enough to establish that the two recovered legacy oxygen-adjacent optimizations are not active hotspots in the currently admitted root-water-uptake production path. It does not establish that oxygen stress is scientifically unimportant or that a later oxygen capability may not be admitted.

## S9 MultiSWAP OxygenStress shared-data reclassification

Recovered authority:

- `README_S9_MULTISWAP_MEMORY_ARCHITECTURE.md`
- `S9_from_S8.patch`
- later cumulative S11 patch confirms the same shared-data architecture but is not treated as an isolated S9 authority

### What S9 actually changes

S9 follows an S6-S8 explicit-context line. Its change is architectural and memory-oriented, not the old duplicate-QROMBD or no-stress runtime shortcut.

The S8 context owned an `OxygenStressCache` per logical column. S9 reclassifies the six cached arrays as immutable-after-construction derived data reachable through shared data. The construction identity includes soil/grid and oxygen settings and, when hysteresis is active, the initial wetting/drying branch used during construction.

The cache is removed from the transactional snapshot because it is not evolving run state.

Recovered component qualification reports:

```text
SHARED_DATA_CLASSIFICATION=PASS
SHARED_DATA_NOT_IN_SNAPSHOT=PASS
TWO_CONTEXTS_CAN_SHARE_ONE_DATASET=PASS
```

Recovered normalized output hashes remain equal between S8 and S9 for the recorded grass and macropore cases, and the sequential OxygenStress A-to-B reinitialization result matches a fresh B run after normalization.

For the documented n=100, five-drain-level example, the recovered payload accounting changes from about 24,776 bytes per S8 context to about 19,976 bytes of mutable per-column state plus a 4,800-byte shared OxygenStress dataset per unique complete construction key.

These are memory-layout results, not a whole-model speedup claim.

### Classification

Historical S8-to-S9 lineage:

**B — EXACT_SEMANTICS_ARCHITECTURE/PERFORMANCE_CANDIDATE, QUALIFIED_WITHIN_ITS_LINEAGE.**

Target A, stable SWAP 4.3.1 maintenance line:

**D — NOT DIRECTLY ADMISSION-READY AGAINST THE AUTHORITATIVE LEGACY BASELINE.**

Reason: S9 depends on the preceding S6-S8 explicit `SwapContext` ownership architecture. Treating `S9_from_S8.patch` as a small standalone legacy maintenance patch would omit required parent semantics. F-PE12 has not recovered and admitted that complete architecture chain against the authoritative stable legacy baseline as one bounded production postimage.

Target B, current SWAP5:

**E — NOT APPLICABLE TO THE CURRENT ADMITTED ROOT-UPTAKE PATH.**

Reason: current SWAP5 has no admitted OxygenStress cache or oxygen process on this root-uptake path. Porting the S9 cache-sharing change would create speculative state for a capability that is not present in the current production owner.

No production mutation is permitted from S9 in F-PE12.

## A23ap root-extraction oxygen-reproduction prefix transform

Recovered authority:

- `A23AP_REPORT.md`
- `A23AP_ROOTEXTRACTION_OXYGEN_CONTRACT.md`

### What A23ap actually changes

A23ap is a later root-extraction ownership/performance change, again distinct from duplicate-QROMBD removal and the fast no-stress exit.

Its bounded physics scope is:

```text
SWOXYGEN=2
SWOXYGENTYPE=2
macro and microscopic root extraction
```

It does not change the physical Bartholomeus oxygen model and does not change Feddes oxygen stress.

The legacy reproduction function recomputed a triangular porosity prefix for each root node. A23ap preserves the operation order of each prefix but maintains the prefix cumulatively in the caller. The pure algebra is moved into an I/O-free contract.

Recovered qualification includes:

```text
100000 frozen-reference checks
0 bitwise mismatches
16116 controlled macro+micro reproduction calls
A23ao and A23ap BAL/BLC byte-identical in the controlled case
legacy repeated prefix terms = 1,295,437
A23ap cumulative prefix terms = 194,924
operation-count reduction = 84.95%
legacy/new addition-count ratio = 6.65x
```

The 6.65x value is explicitly an addition-count ratio for the prefix operation. It is not a measured 6.65x root-extraction or whole-SWAP speedup.

The change adds no persistent physical column state and no profile scratch array. Recovered accounting adds two call-local real scalars only.

The A23ao-to-A23ap patch was also applied to a fresh A23ao source tree and the recorded production build, controlled reproduction case, BAL/BLC hashes and A23ap statistics all reproduced.

### Remaining lineage boundary

The A23ap report explicitly leaves the formal cumulative rebase onto the original A23y production facade open.

That prevents F-PE12 from treating the locally qualified A23ao-to-A23ap delta as a directly admitted patch against the authoritative stable SWAP 4.3.1 target.

### Classification

Historical A23ao-to-A23ap lineage:

**B — EXACT_SEMANTICS_LOCAL_PERFORMANCE_CANDIDATE, LOCALLY QUALIFIED.**

Target A, stable SWAP 4.3.1 maintenance line:

**D — LINEAGE/REBASE NOT CLOSED AGAINST THE AUTHORITATIVE TARGET.**

The local child/parent qualification is real evidence, but it does not substitute for the still-open cumulative production-facade rebase. F-PE12 must not silently reconstruct that lineage.

Target B, current SWAP5:

**E — NOT APPLICABLE TO THE CURRENT ADMITTED ROOT-UPTAKE PATH.**

The current production root-uptake owner implements only macro Feddes drought uptake and contains none of the A23ap oxygen-reproduction route. Adding the prefix contract now would therefore be a new capability implementation, not a current-hotspot performance optimization.

No production mutation is permitted from A23ap in F-PE12.

## Relationship to the earlier OxygenStress experiments

The following classifications remain unchanged:

| Candidate | F-PE12 status | Reason |
| --- | --- | --- |
| duplicate-QROMBD removal | D | historical existence known, isolated exact postimage and qualification not recovered |
| fast no-stress exit | D | historical existence known, isolated exact postimage and qualification not recovered |
| S9 shared OxygenStress data | B in historical S8-S9 lineage; D for direct Target-A admission; E for current Target B | separate architecture/memory line with parent dependencies |
| A23ap cumulative oxygen-reproduction prefix | B in historical A23ao-A23ap lineage; D for direct Target-A admission; E for current Target B | locally exact-qualified but cumulative production rebase open |

No later result is allowed to backfill missing evidence for an earlier candidate merely because all four touch OxygenStress or root uptake.

## IMPLEMENT decision for the oxygen-adjacent set

```text
TARGET_A_S9 = NO_MUTATION_PARENT_LINEAGE_NOT_ADMITTED
TARGET_A_A23AP = NO_MUTATION_CUMULATIVE_REBASE_OPEN
TARGET_B_S9 = NO_MUTATION_NOT_APPLICABLE_TO_CURRENT_ADMITTED_PATH
TARGET_B_A23AP = NO_MUTATION_NOT_APPLICABLE_TO_CURRENT_ADMITTED_PATH
EARLIER_DUPLICATE_QROMBD = NO_MUTATION_INSUFFICIENT_PROVENANCE
EARLIER_NO_STRESS_EXIT = NO_MUTATION_INSUFFICIENT_PROVENANCE
```

This closes the OxygenStress-adjacent recovery without source changes.

## Reopen conditions

This disposition may be revisited only if at least one of the following occurs:

1. an exact isolated earlier OxygenStress patch plus its matching qualification package is recovered;
2. the complete S6-S9 legacy parent chain is intentionally nominated for admission as its own architecture workunit;
3. the A23y-through-A23ap cumulative production-facade rebase is recovered and independently qualified against an authoritative legacy target;
4. a real oxygen-stress capability is later admitted into SWAP5, creating a new target-B dependency surface.
