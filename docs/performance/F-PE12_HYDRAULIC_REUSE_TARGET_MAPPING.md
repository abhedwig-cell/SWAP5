# F-PE12 — Hydraulic performance target mapping

Date: 2026-09-16

This record closes the target mapping for the recovered SWAP-011 hydraulic-performance line before any production mutation is considered.

## Authorities

SWAP5:

- canonical branch: `integration/f-ci-canonical`
- live canonical commit used for this mapping: `80c6faaa8a277d9596a6da7bc5d2244c0df1bb82`
- live canonical tree: `9b3ee78c9ff5dfde12345ef4e472e74d41ac0da3`
- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`

Legacy corrected-reference line:

- immutable SWAP 4.3.1 B0 remains the preimage authority;
- current canonical corrected-reference manifest is B1.10;
- B1.10 does **not** contain SWAP-011;
- SWAP-011 candidate authority recovered from branch `b1-swap011-candidate`, head `35b761f6e10fe32e438b32b94948b4b3a905f50a`;
- issue #12 remains open for recovery of the exact final E7 patch payload.

## Classification correction after deeper recovery

The first F-PE12 pass correctly identified E2/E3 as evidence that explicit K/dKdh reuse can be made state-safe. It did not yet recover the later E5/E6/E7 production-candidate record.

That later record changes the historical interpretation.

E3 was an intermediate semantic prototype. It added per-node derivative storage and a `hconduc_dh` interface to test solver lifetime and invalidation rules, but it was not compiled or executed in that workspace.

The later qualified E5/E6/E7 line did **not** retain that `headcalc`-storage design as its final production form. The recovered SWAP-011 dossier records a final optimized implementation whose production source changes are limited to:

```text
MOD_MvG_functions.f90
WC_K_models_04_11.f90
MOD_RIA.f90
```

and for which `headcalc.f90` remains byte-identical to B0.

The dossier describes the final route as using model-specific/lazy constitutive state with a finite-difference fallback only where required for numerical or branch safety. Therefore the final qualified historical candidate is a constitutive-level optimized SWAP-011 correction, not the earlier E3 per-node-storage prototype.

## Target A — SWAP 4.3.1

### Scientific/correctness status

The SWAP-011 defect remains a correctness item: the implicit Richards Jacobian derivative must correspond to the actually selected conductivity relation.

The deliberately expensive numerical derivative remains the correctness oracle for the affected models.

### Final optimized implementation status

Recovered qualification evidence for the later production candidate is substantial:

- E5: 36/36 strict full runs passed;
- E5 Newton routes matched the qualified reference route exactly;
- E5 `result.end` was byte-identical in the gate cases;
- measured E5 improvement versus the numerical-reference implementation was about 9.0% to 19.2%, median about 12.3%;
- E6: 150/150 runs completed normally;
- E6: 60/60 D2/reference versus optimized-candidate Newton routes matched exactly;
- E6 K0 outputs were 30/30 byte-identical;
- E6 K1 outputs were 16/30 byte-identical, with the remaining differences reported at round-off scale;
- maximum reported E6 H-RMSE was `1.43e-11 cm`;
- maximum reported nodal deviation was `9.98e-11 cm`;
- median optimized/reference runtime ratio was `0.791`, about 20.9% faster;
- a 31/31 follow-up timing set was faster for the optimized implementation;
- E7 removed unused exploratory derivative wrappers, retained the lazy-state/fallback production route, and retained focused exact Newton histograms and byte-identical `result.end` in the recorded sanity set.

Historical audit status after E7:

```text
FIX_TESTED
READY_PATCH_UPSTREAM
```

### Provenance gate

The exact final E7 patch payload is still missing from the integrated repository and was not found in the File Library recovery search performed by F-PE12.

Expected artifact names remain:

```text
SWAP_4.3.1_E7_SW011_upstream_package.zip
SWAP_4.3.1_SW011_overdracht_Marius.docx
SWAP_4.3.1_SW011_overdracht_Marius_bundle.zip
patch/SWAP-011_fix.patch
```

The recovered `SWAP_4.3.1_proposed_fixes.patch` is an earlier broad numerical-reference patch and is explicitly not the E7 payload.

The anti-reconstruction rule therefore remains binding: the final implementation must not be recreated from the algorithm description, even though its scientific and numerical qualification is well documented.

### Target-A disposition

The recovered historical objects now separate cleanly:

- SWAP-011 defect/correctness requirement: **A — CORRECTNESS_FIX**;
- E3 explicit per-node reuse prototype: **E — SUPERSEDED_BY_LATER_QUALIFIED_LEGACY_IMPLEMENTATION** for Target A;
- E5/E6/E7 optimized SWAP-011 implementation: **B — EXACT_SEMANTICS_PERFORMANCE_CANDIDATE, TECHNICALLY_QUALIFIED_BUT_PROVENANCE_BLOCKED**.

This B status is intentionally not B1 admission. B1.10 still excludes SWAP-011 because the exact final E7 bytes are unavailable.

No Target-A source mutation is permitted until the original E7 payload is recovered and byte-verified against B0.

## Target B — current SWAP5

The current admitted SWAP5 hydraulic ownership is materially different from legacy SWAP 4.3.1.

### Current value provider

`src/solver/mod_b110_default_mvg_provider.f90` owns the current default B1.10 value-provider path. Its normal evaluation computes water content, moisture capacity and conductivity, then explicitly records:

```text
swkimpl=1 is deliberately not admitted by F-SI09
```

and sets the common-interface `dconductivity_dhead` output to zero.

This is positive code evidence that the legacy SWKIMPL=1 inner-Newton K/dKdh duplication is not an active admitted hotspot in the current SWAP5 default value-provider path.

### Directional derivative capability

`src/solver/mod_b110_default_mvg_directional_provider.f90` separately supplies smooth-region directional derivatives, including `dkdh`, for sensitivity/directional semantics. It explicitly leaves the value-provider derivative slot reserved.

That sibling capability must not be treated as proof that SWKIMPL=1 has been admitted, nor as an automatic identity claim with the legacy Newton-Jacobian derivative path.

### Architecture mapping

The hydraulic migration map already assigns legacy `MOD_MvG_functions.f90`, `WC_K_models_04_11.f90` and `MOD_RIA.f90` to an explicit constitutive/hydraulic service and decomposes `headcalc.f90` behind solver contracts. The current code follows that ownership direction.

For the current admitted target, there is therefore no active legacy-equivalent duplicated K plus Jacobian-dKdh path to optimize with the recovered E7 concept.

### Target-B disposition

The historical SWAP-011 performance implementation is:

**E — OBSOLETE_OR_NOT_APPLICABLE_FOR_THE_CURRENT_ADMITTED_SWAPP5_VALUE_PATH.**

This class E is bounded to the current admitted target. It does not state that SWKIMPL=1 can never return, and it does not prohibit reuse of the historical qualification strategy if an implicit-conductivity Jacobian mode is admitted later.

A future admission of `conductivity_implicit_mode` / SWKIMPL=1 semantics would create a new dependency surface and require a fresh applicability decision.

## IMPLEMENT decision

No production source change is justified in this F-PE12 state.

- Target A has a technically qualified historical implementation but is fail-closed on missing exact E7 patch bytes.
- Target B does not currently execute the legacy derivative hotspot in its admitted value-provider path.
- Reconstructing E7 from E2/E3 or prose would violate provenance.
- Porting E7 into SWAP5 now would optimize a currently non-admitted execution path and would therefore be speculative work outside the bounded campaign.

IMPLEMENT disposition:

```text
TARGET_A = BLOCKED_EXACT_E7_PAYLOAD_REQUIRED
TARGET_B = NO_MUTATION_NOT_APPLICABLE_TO_CURRENT_ADMITTED_PATH
```

## Next permitted action

1. Perform one final bounded provenance search for the exact E7 package/patch without recreating it.
2. If exact bytes remain unavailable, preserve issue #12 as the external recovery gate and close the Target-A implementation attempt as provenance-blocked.
3. Do not create a substitute E7 implementation.
4. Do not modify current SWAP5 production source for this hydraulic candidate.
5. Continue F-PE12 only with another independently recovered candidate if it has exact-enough provenance and an active target hotspot; otherwise proceed to workunit closeout.
