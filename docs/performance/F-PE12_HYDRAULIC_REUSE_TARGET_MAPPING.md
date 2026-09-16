# F-PE12 - Hydraulic performance target mapping

Date: 2026-09-16

This record maps the recovered SWAP-011 hydraulic-performance line before any production mutation is considered.

## Authorities

SWAP5:

- canonical branch: `integration/f-ci-canonical`
- live canonical commit: `80c6faaa8a277d9596a6da7bc5d2244c0df1bb82`
- live canonical tree: `9b3ee78c9ff5dfde12345ef4e472e74d41ac0da3`
- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`

Legacy corrected-reference line:

- immutable SWAP 4.3.1 B0 remains the preimage authority;
- current canonical corrected-reference manifest is B1.10;
- B1.10 does not contain SWAP-011;
- SWAP-011 candidate authority was recovered from branch `b1-swap011-candidate`, head `35b761f6e10fe32e438b32b94948b4b3a905f50a`;
- issue #12 remains open for recovery of the exact final E7 patch payload.

## Historical lineage correction

The first F-PE12 pass identified E2/E3 as evidence that explicit K/dKdh reuse can be made state-safe. Deeper recovery found the later E5/E6/E7 production-candidate record.

E3 was an intermediate semantic prototype. It added per-node derivative storage and a `hconduc_dh` interface to test solver lifetime and invalidation rules, but it was not compiled or executed in that workspace.

The later qualified E5/E6/E7 line did not retain that `headcalc` storage design as its final production form. The recovered SWAP-011 dossier records a final optimized implementation whose production source changes are limited to:

```text
MOD_MvG_functions.f90
WC_K_models_04_11.f90
MOD_RIA.f90
```

with `headcalc.f90` byte-identical to B0.

The final route uses model-specific/lazy constitutive state with a finite-difference fallback where required for numerical or branch safety. It is therefore a constitutive-level optimized SWAP-011 correction, not the earlier E3 per-node-storage prototype.

## Target A - SWAP 4.3.1

### Scientific status

The SWAP-011 defect remains a correctness item: the implicit Richards Jacobian derivative must correspond to the selected conductivity relation.

The deliberately expensive numerical derivative remains the correctness oracle for affected models.

### Recovered optimized qualification

The recovered later production-candidate evidence records:

- E5: 36/36 strict full runs passed;
- E5 Newton routes matched the qualified reference route exactly;
- E5 `result.end` was byte-identical in the gate cases;
- E5 timing improvement versus the numerical-reference implementation was about 9.0% to 19.2%, median about 12.3%;
- E6: 150/150 runs completed normally;
- E6: 60/60 D2/reference versus optimized-candidate Newton routes matched exactly;
- E6 K0 outputs were 30/30 byte-identical;
- E6 K1 outputs were 16/30 byte-identical, with remaining differences reported at round-off scale;
- maximum reported E6 H-RMSE was `1.43e-11 cm`;
- maximum reported nodal deviation was `9.98e-11 cm`;
- median optimized/reference runtime ratio was `0.791`, about 20.9% faster;
- a 31/31 follow-up timing set was faster for the optimized implementation;
- E7 removed unused exploratory derivative wrappers while retaining the lazy-state/fallback route and focused exact Newton/result evidence.

Historical audit status after E7:

```text
FIX_TESTED
READY_PATCH_UPSTREAM
```

### Provenance gate

The exact final E7 patch payload is still missing from the integrated repository and was not recovered by F-PE12.

Expected artifact names remain:

```text
SWAP_4.3.1_E7_SW011_upstream_package.zip
SWAP_4.3.1_SW011_overdracht_Marius.docx
SWAP_4.3.1_SW011_overdracht_Marius_bundle.zip
patch/SWAP-011_fix.patch
```

The recovered `SWAP_4.3.1_proposed_fixes.patch` is an earlier broad numerical-reference patch and is not the final E7 payload.

The anti-reconstruction rule remains binding. The final implementation must not be recreated from the algorithm description even though its scientific and numerical qualification is well documented.

### Target-A disposition

- SWAP-011 defect/correctness requirement: **A - CORRECTNESS_FIX**.
- E3 explicit per-node reuse prototype: **E - SUPERSEDED_BY_LATER_QUALIFIED_LEGACY_IMPLEMENTATION** for Target A.
- E5/E6/E7 optimized SWAP-011 implementation: **B - EXACT_SEMANTICS_PERFORMANCE_CANDIDATE, TECHNICALLY_QUALIFIED_BUT_PROVENANCE_BLOCKED**.

This B status is not B1 admission. B1.10 still excludes SWAP-011 because the exact final E7 bytes are unavailable.

No Target-A source mutation is permitted until the original E7 payload is recovered and byte-verified against B0.

## Target B - current SWAP5

Deeper code mapping requires a narrower conclusion than the earlier preliminary class-E wording.

### Admitted typed production profile

`src/adapter/mod_b110_production_soil_water_task2.f90` contains the production-route gate:

```fortran
if (swkimpl /= 0) return
```

The qualified typed F-SI33 production route therefore does not execute the implicit-conductivity Newton derivative path for which the historical K/dKdh optimization was designed.

The same source retains a legacy compatibility solver behind the common solver interface. That compatibility path is not the qualified explicit Full Richards production profile.

### Current HeadCalc compatibility path

Current legacy-port source:

`src/legacy/b1_10_port/headcalc.f90`

Current blob recorded during the mapping:

`3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55`

The explicit-provider path already has worker-owned constitutive scratch including provider K and derivative-related arrays. This is an architectural seam only. It does not establish admitted SWKIMPL=1 semantics.

When `SwKimpl == 1`, the current compatibility HeadCalc path still uses legacy derivative/conductivity calls in the Newton route. Therefore the old hotspot has not been proven removed from every compatibility execution surface.

### Provider derivative distinction

`src/solver/mod_b110_default_mvg_provider.f90` deliberately leaves the value-provider `dconductivity_dhead` slot at zero for the non-admitted SWKIMPL=1 mode.

`src/solver/mod_b110_default_mvg_directional_provider.f90` owns a separate smooth directional derivative capability. That derivative has different capability ownership, call timing and qualification semantics and must not be repurposed as the Newton Jacobian derivative by analogy alone.

### Corrected Target-B disposition

The historical K/dKdh concept is:

**B - DESIGN CANDIDATE, DEFERRED OUTSIDE THE CURRENT STATUS-A TYPED PRODUCTION PROFILE.**

This supersedes the earlier preliminary statement that it was class E for all current SWAP5 execution surfaces.

The bounded facts are:

- the admitted typed production profile excludes SWKIMPL=1;
- a compatibility path still contains legacy SWKIMPL=1 K/dKdh work;
- the current worker ownership would provide a plausible future explicit scratch location;
- no admitted Newton derivative contract exists on the typed production profile;
- F-PE12 must not broaden the production profile merely to create a performance target.

A future capability that admits implicit-conductivity semantics on the explicit typed solver path may reuse the historical qualification strategy, but it requires its own scientific and numerical admission before performance work.

## IMPLEMENT decision

No production source change is justified in F-PE12.

```text
TARGET_A = BLOCKED_EXACT_E7_PAYLOAD_REQUIRED
TARGET_B = DEFERRED_OUTSIDE_CURRENT_ADMITTED_TYPED_PROFILE
```

Reasons:

- reconstructing E7 from E2/E3 or prose would violate provenance;
- the current admitted Target-B production route does not execute the historical hotspot;
- changing solver admission merely to expose a benchmark target would broaden scientific scope;
- the compatibility path is not sufficient authority for a new Status-A production performance claim.

## Reopen conditions

Target A may be reopened if the exact E7 package/patch is recovered and byte-verified.

Target B may be reopened if implicit-conductivity/SWKIMPL=1 semantics are independently admitted on the explicit typed solver path or another current production route is formally nominated as the performance target.

Until one of those conditions is met, F-PE12 makes no hydraulic production mutation.
