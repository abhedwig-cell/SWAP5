# F-PE12 — K / dKdh target-mapping checkpoint

Date: 2026-09-16

Workunit: `F-PE12 — Dual-target performance recovery`

Protocol position: `RECONCILE -> CLASSIFY -> TARGET MAPPING`, before any implementation.

This checkpoint narrows the only retained exact-semantics performance concept from the first classification pass: explicit per-node conductivity / conductivity-derivative reuse. It does not change production or reference source.

## Pinned authorities

SWAP5:

- canonical branch: `integration/f-ci-canonical`
- live canonical commit rechecked immediately before this checkpoint: `80c6faaa8a277d9596a6da7bc5d2244c0df1bb82`
- live canonical tree: `9b3ee78c9ff5dfde12345ef4e472e74d41ac0da3`
- current Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`

Work branch before this checkpoint:

- `work/f-pe12-dual-target-performance-recovery`
- CLASSIFY checkpoint head: `2238c26f9059a9ccc7ab91500587bc7014696320`

The live canonical has not advanced since the first F-PE12 classification pass.

## Target A — SWAP 4.3.1 stable maintenance/performance line

### What is exact

The byte-defined B0 source identity is already pinned under `reference/swap-4.3.1/b0/`.

An immutable B1.10 snapshot of `SWAP/MOD_MvG_functions.f90` is also present under `reference/swap-4.3.1/b1_10_source/`; its decoded source SHA-256 is:

`4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1`

That snapshot is reference/qualification material. It is not permission to reconstruct later performance experiments.

GitHub issue #12 remains the hard provenance boundary for the final qualified SWAP-011 correction. The expected final production source set is:

- `SWAP/MOD_MvG_functions.f90`
- `SWAP/WC_K_models_04_11.f90`
- `SWAP/MOD_RIA.f90`

and `SWAP/headcalc.f90` is expected to remain byte-identical. The issue explicitly prohibits reconstruction of the qualified patch from prose or memory.

### What is not exact

The recovered E2 and E3 records establish a defensible design and call-lifetime argument for explicit K / dKdh reuse. They do not provide the exact runnable E1 performance-candidate source bytes or the exact final E7 corrected source package on which a production optimization should be based.

Repeated File Library recovery using the distinctive E1 symbols and descriptions, including `derivativevalue_04_11`, `functionvalue_04_11`, `hconduc_dh`, `SWAP_4.3.1_E1`, and the model-specific analytical derivative description, recovered E2/E3 design records but no isolated E1 source/patch artifact.

The older broad `SWAP_4.3.1_proposed_fixes.patch` is not a substitute. Issue #12 already records that it contains the earlier numerical finite-difference reference implementation plus unrelated fixes and is not the final qualified SWAP-011 patch.

### Target-A disposition

The explicit K / dKdh reuse concept remains scientifically plausible as a **B design candidate**, but **IMPLEMENT is not permitted on target A from the currently recovered evidence**.

Reason: implementing now would require reconstructing either the corrected derivative authority, the E1 performance postimage, or both from narrative/static-analysis evidence. That violates the source-provenance rule already established for SWAP-011.

Required unlock is one of:

1. recovery of the exact qualified E7 SWAP-011 package/patch and the exact E1 candidate source/patch needed to reproduce the measured performance lineage; or
2. an explicitly new optimization workunit that starts from an admitted corrected legacy source postimage and independently derives, tests and qualifies a new implementation rather than claiming recovery of E1/E3.

F-PE12 must not silently turn recovery into reimplementation.

## Target B — current SWAP5 Status-A line

### The admitted typed production profile excludes SWKIMPL=1

`src/adapter/mod_b110_production_soil_water_task2.f90` contains the explicit production-route gate:

```fortran
if (swkimpl /= 0) return
```

Therefore the qualified typed F-SI33 production route does not execute the implicit-conductivity Newton derivative path for which the historical K / dKdh reuse candidate was designed.

The same file deliberately retains a legacy compatibility solver behind the common solver interface. Its own comments state that this compatibility implementation preserves B1.10 behaviour but is **not promoted to the qualified explicit Full Richards production profile**.

This distinction is decisive for F-PE12: a hotspot on the compatibility path is not automatically a current Status-A performance target.

### Current HeadCalc mapping

The live source is:

`src/legacy/b1_10_port/headcalc.f90`

with current blob:

`3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55`

The explicit-provider path already materializes constitutive outputs in worker-owned workspace arrays:

- `provider_theta`
- `provider_k`
- `provider_capacity`
- `provider_dkdh`
- `dconductivity_dhead`

The workspace is reset explicitly, so the architecture already has a suitable ownership location for a future derivative value. That is an architectural seam, not evidence that Newton dK/dh semantics are admitted.

At the start of the Newton iteration, when `SwKimpl == 1`, current HeadCalc still computes the Jacobian derivative using the legacy constitutive routine:

```fortran
fsi_ws%dconductivity_dhead(i) = dhconduc(...)
```

It does not consume `fsi_ws%provider_dkdh` as the Newton derivative authority.

After a trial/backtracking head update, the same `SwKimpl == 1` branch recomputes conductivity with legacy:

```fortran
state%k(i) = hconduc(...)
```

rather than using the provider K materialized by the explicit provider call.

This is consistent with the current value-provider contract. `src/solver/mod_b110_default_mvg_provider.f90` deliberately sets `dconductivity_dhead = 0.0_real64` and records that `swkimpl=1` was not admitted by the owning solver-interface capability; the output slot remains reserved.

### F-SI37 directional derivative is not the Newton derivative

`src/solver/mod_b110_default_mvg_directional_provider.f90` owns an analytically differentiated smooth directional capability used by the accepted-step directional-sensitivity chain. Its contract deliberately leaves the value-provider `dconductivity_dhead` slot unchanged.

That derivative must not be repurposed as an implicit-conductivity Newton Jacobian derivative merely because both have units of dK/dh. They have different capability ownership, smoothness/fail-closed semantics, call timing and qualification authority.

### Target-B disposition

The recovered historical K / dKdh optimization is **not applicable to the current admitted Status-A typed production profile**, because that profile excludes `SWKIMPL=1`.

It is also **not classified as already implemented/superseded**:

- the worker workspace has appropriate explicit scratch;
- but the Newton path still uses legacy `dhconduc` / `hconduc` when `SWKIMPL=1`;
- and the provider derivative slot is not the admitted Newton authority.

The correct disposition is therefore:

`B DESIGN CANDIDATE, DEFERRED OUTSIDE CURRENT STATUS-A PRODUCTION PROFILE`

A SWAP5 implementation would belong to a separate future capability that first admits implicit-conductivity semantics on the explicit typed solver path. Such a capability would need independent scientific/numerical qualification of the derivative contract before any performance claim.

F-PE12 must not broaden the Status-A solver profile merely to create a benchmark target.

## Implementation decision

For the currently recovered candidate set, **no production implementation is permitted in F-PE12**.

This is not a failure to find a code edit. It is the bounded result of the target mapping:

- target A: exact source/postimage provenance is insufficient for recovery-based implementation;
- target B: the hotspot lies outside the admitted Status-A typed production profile;
- WFT300 remains excluded from exact-semantics work;
- hidden mutable caches remain excluded;
- the OxygenStress candidates and other historical candidates still lack isolated admission-grade evidence.

Consequently the IMPLEMENT phase has the disposition:

`NO_SAFE_APPLICABLE_IMPLEMENTATION_FROM_RECOVERED_AUTHORITIES`

No source should be changed merely to force this phase to produce a patch.

## Qualification required for closeout

The remaining F-PE12 qualification is a recovery/governance qualification, not a speed qualification:

1. verify the branch delta contains documentation only;
2. verify canonical did not move relative to the mapped source surfaces;
3. verify the named current blobs and route gate remain unchanged;
4. verify no EB or RossFast source was touched;
5. record that no performance or equivalence claim was made without runnable evidence;
6. close the workunit as a bounded recovery result, with the two explicit future unlock conditions above.

No benchmark rerun is meaningful or required because F-PE12 has produced no executable performance candidate.
