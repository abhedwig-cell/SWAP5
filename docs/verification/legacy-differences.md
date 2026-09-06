# Legacy difference ledger

## Purpose

This ledger is the authoritative map of intentional numerical or behavioural differences between the immutable B0 audit baseline and the corrected B1 reference line. An unexplained B0/B1 difference is a verification failure until classified.

## Admission states

| State | Meaning |
| --- | --- |
| `OBSERVED` | discrepancy detected; cause not yet established |
| `BUG_CONFIRMED` | legacy implementation defect demonstrated |
| `FIX_TESTED` | candidate legacy repair has passed its defined qualification |
| `PATCH_PAYLOAD_PENDING` | fix is qualified, but the exact qualified patch artifact has not yet passed B1 provenance checks |
| `ADMITTED_B1` | qualified correction is included in the current corrected-reference patch set |
| `PROVENANCE_REPAIR` | identity metadata repaired without intended numerical/model change |
| `MODEL_CHANGE` | intentional model development; never silently folded into B1 |
| `DOC_ONLY` | documentation correction without B1 numerical change |

Admission requires exact patch provenance, canonical B0 preimage verification, ordered preimage verification when patches share a target, qualification evidence and inclusion in the ordered B1 manifest.

## Admitted B0 -> B1 differences

| First snapshot | Audit ID | Classification | B0 behaviour | B1 correction | Qualification evidence |
| --- | --- | --- | --- | --- | --- |
| `B1.1` | `SWAP-001` | code bug | non-conformable whole-array macropore assignment possible | clear destination and copy active conformable slice | strict mismatch reproducer + corrected smoke run |
| `B1.2` | `SWAP-005` | bounds/portability bug | `.AND.` may evaluate `cropstart(i+1)` before bound guard | guard `i < ifnd` before `i+1` access | source-bound signaling-NaN gate |
| `B1.3` | `SWAP-006` | initialization/portability bug | meteo scan relies on unused zero-initialized sentinel | iterate exactly over `1:ifnd` | source-bound signaling-NaN gate |
| `B1.4` | `SWAP-007` | numerical robustness bug | tiny nonzero derivative can overflow Newton quotient | only divide if quotient representable; otherwise existing restart path | strict FPE case + unchanged ordinary control |
| `B1.5` | `SWAP-008` | Fortran correctness bug | consumed arrays declared `INTENT(OUT)` | use `INTENT(INOUT)` without arithmetic change | band-solver harness |
| `B1.6` | `SWAP-009` | PDI hydraulic code bug | `abs(h)` passed to signed Kelvin relation | pass signed `h` | strict PDI function gate + full PDI run + mass gate |
| `B1.7` | `SWAP-010` | model-7 algebra bug | capacity not derivative of implemented retention curve | use consistent weighted common denominator | derivative gate + sensitive full model-7 run |
| `B1.8` | `SWAP-013` | PDI input-domain bug | singular `HA=0` / `HA>=H0` accepted | require `0 < HA < H0` for PDI models 8-11 | 9-case source-bound guard gate |
| `B1.9` | `SWAP-012` | hydraulic inverse algorithm bug | models 3 and 5-12 fall through to unrelated default-MvG `prhead` inverse | numerically invert the selected retention relation; retain model-4 analytical control | D2 22,240-point gate + isolated actual-source 600-point gate |

Machine-readable scopes are in `docs/verification/expected-differences.json`. An admitted correction permits only its documented difference envelope.

## Provenance repair: B1.5 -> B1.5p1

B1.5p1 repaired incorrect historical patch/preimage identity metadata discovered by VQ-1c without changing the intended five corrected source results. Historical B1.2-B1.5 remain audit records and are not exact executable oracles.

## B1.5p1 -> B1.8 summary

B1.6 admitted SWAP-009 with exact source provenance, direct constitutive verification, a representative full PDI run and hard legacy mass evidence. B1.7 admitted SWAP-010 and explicitly pinned the ordered B1.6 preimage because SWAP-009 and SWAP-010 share `WC_K_models_04_11.f90`. B1.8 admitted SWAP-013 as an input-validation-only difference for singular PDI `HA/H0` combinations.

## B1.8 -> B1.9: SWAP-012 admission

SWAP-012 targets `SWAP/MOD_MvG_functions.f90`, unchanged by all previously admitted B1 patches, so the canonical B0 and ordered B1.8 preimages are identical:

```text
canonical B0 / ordered B1.8 preimage
a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390

stored SWAP-012 patch
263e515b7c80059c13e71fcbc3dc1f187b6d0673e07c0c265bbc140fea0df131

corrected target
4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1
```

The historical broad patch also contained SWAP-011 work. B1.9 explicitly excludes all `dhconduc`/Jacobian derivative changes and admits only the `prhead` inverse correction.

D2 tested 22,240 valid affected-model round trips: the legacy inverse produced 17,176 errors above `0.01` decade, the corrected inverse produced 0 failures, maximum corrected error `2.09e-8` decade. A separate strict actual-source test of 60 pressure heads for each model 3-12 gave 513/600 B0 failures and 0/600 corrected failures at `1e-6` decade, with maximum corrected error `1.17e-10` decade. Model 4 remained the unaffected analytical control.

Deterministic B1.9 identity:

```text
members          63
source bytes      1,863,300
manifest SHA-256  5e28510813e5748bae52ffd5c08027bb55b63858aa994ea90635b632826de657
```

SWAP-012 changes no retention/conductivity formulation, Richards residual/Jacobian, solver policy or mass tolerance. This is an implementation-correctness repair, not model development.

## Audit findings waiting for B1 admission review

| Audit ID | State | Finding | Qualified correction status | Remaining gate |
| --- | --- | --- | --- | --- |
| `SWAP-011` | `PATCH_PAYLOAD_PENDING` | `dhconduc` derivative inconsistent with implemented `K(h)` for several models | E5/E6/E7 `FIX_TESTED` / `READY_PATCH_UPSTREAM` | recover exact final E7 patch and verify exact provenance |

## Rule for SWAP 5 verification

```text
if current B1 exact identity/qualification gate != PASS:
    reference equivalence is BLOCKED
elif B2 == pinned B1 within tolerance:
    reference equivalence passes
elif difference is an explicitly qualified SWAP 5 model change:
    evaluate against that change's acceptance criteria
else:
    fail as unexplained divergence
```

This prevents known bugs from being recreated for compatibility while preserving a complete explanation for every intentional departure from legacy SWAP 4.3.1.
