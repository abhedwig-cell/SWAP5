# F-PE12 - Target-mapping checkpoint

Date: 2026-09-16

Workunit: `F-PE12 - Dual-target performance recovery`

Protocol position: after `RECONCILE -> CLASSIFY`, before the no-mutation IMPLEMENT disposition.

This checkpoint records why the retained hydraulic performance concept does not justify production modification on either target.

## Pinned authorities

SWAP5:

- canonical branch: `integration/f-ci-canonical`
- live canonical commit: `80c6faaa8a277d9596a6da7bc5d2244c0df1bb82`
- live canonical tree: `9b3ee78c9ff5dfde12345ef4e472e74d41ac0da3`
- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`

Target A:

- immutable SWAP 4.3.1 B0 remains the source preimage authority;
- B1.10 is the current corrected-reference manifest;
- B1.10 does not include SWAP-011;
- issue #12 remains the provenance gate for the exact final E7 SWAP-011 patch payload.

## Target A mapping

The recovered E2/E3 records establish that an explicit K/dKdh reuse design can be state-safe, but E3 is only an intermediate semantic prototype.

Deeper recovery found the later E5/E6/E7 SWAP-011 optimized lineage. That lineage was broadly qualified and was historically marked `FIX_TESTED` / `READY_PATCH_UPSTREAM`.

Its final production source set is recorded as:

```text
MOD_MvG_functions.f90
WC_K_models_04_11.f90
MOD_RIA.f90
```

with `headcalc.f90` byte-identical to B0.

The exact final E7 patch/package bytes are not present in the integrated repository and were not recovered by F-PE12. The earlier broad `SWAP_4.3.1_proposed_fixes.patch` is not the final E7 payload.

Therefore:

```text
SWAP-011 defect = A correctness authority
E3 reuse prototype = superseded for Target A
E5/E6/E7 optimized implementation = B technically qualified, provenance blocked
```

F-PE12 may not reconstruct E7 from prose, expected file names or earlier prototypes.

## Target B mapping

The current qualified typed production route does not admit the historical implicit-conductivity hotspot.

`src/adapter/mod_b110_production_soil_water_task2.f90` contains the route gate:

```fortran
if (swkimpl /= 0) return
```

So the current Status-A typed production profile excludes SWKIMPL=1.

At the same time, the legacy compatibility HeadCalc path still contains SWKIMPL=1 K/dKdh work. The historical concept is therefore not globally obsolete in the source tree.

The current value-provider derivative slot is deliberately not the admitted Newton derivative authority, and the directional derivative capability has separate ownership and qualification semantics.

Correct Target-B disposition:

```text
B DESIGN CANDIDATE
DEFERRED OUTSIDE CURRENT STATUS-A TYPED PRODUCTION PROFILE
```

This means F-PE12 must not broaden the solver profile merely to expose a benchmark target.

## Oxygen-adjacent mapping result

Later recovered S9 and A23ap evidence does not qualify the earlier duplicate-QROMBD or fast no-stress OxygenStress experiments.

- S9 is qualified within an S8-to-S9 explicit-context/memory lineage but requires its parent architecture for direct Target-A admission.
- A23ap is locally exact-qualified within A23ao-to-A23ap, but its cumulative production-facade rebase remains open.
- current SWAP5 root-water-uptake production exposes only the Feddes drought process and has no admitted OxygenStress cache or oxygen-reproduction route.

Accordingly neither S9 nor A23ap justifies an F-PE12 production mutation.

## IMPLEMENT disposition

```text
TARGET_A_HYDRAULIC = BLOCKED_EXACT_E7_PAYLOAD_REQUIRED
TARGET_B_HYDRAULIC = DEFERRED_OUTSIDE_CURRENT_ADMITTED_TYPED_PROFILE
TARGET_A_S9 = NO_MUTATION_PARENT_LINEAGE_NOT_ADMITTED
TARGET_A_A23AP = NO_MUTATION_CUMULATIVE_REBASE_OPEN
TARGET_B_OXYGEN = NO_MUTATION_NOT_APPLICABLE_TO_CURRENT_ADMITTED_PATH
```

WFT300 and hidden mutable cache forms remain excluded from the exact-semantics path. Other D-class candidates remain blocked by insufficient exact evidence.

Final IMPLEMENT result:

`NO_SAFE_APPLICABLE_IMPLEMENTATION_FROM_RECOVERED_AUTHORITIES`

## Qualification implication

Because no executable production candidate is produced, F-PE12 does not perform a synthetic benchmark merely to complete the protocol.

Qualification for closeout is repository/governance qualification:

1. canonical authority remains unchanged;
2. final work-branch delta is documentation only;
3. no production or legacy source was modified;
4. no EB or RossFast source was modified;
5. no historical speed result is widened beyond its recorded scope;
6. no D-class candidate is recreated from narrative evidence.

The final workunit verdict is recorded in `F-PE12_CLOSEOUT.md`.
