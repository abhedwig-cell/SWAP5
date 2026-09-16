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
| `B1.10` | `SWAP-002` | tillage control-flow/state-initialization bug | impossible interval test can retain the wrong next-event pointer when a run starts after the first event | choose first event on/after start and load the most recent previous tillage parameter state | historical semantic test + fresh strict compiled 3/6 -> 6/6 gate |
| `B1.11` | `SWAP-011` | hydraulic Jacobian derivative bug | implicit Richards Jacobian uses the default MvG `dK/dh` for hydraulic models whose implemented `K(h)` differs | differentiate the actual active conductivity relation using the qualified model-specific/lazy-state implementation with bounded fallback | historical E5/E6/E7 + F-PE19 current-B1 qualification + full canonical B0 replay |

Machine-readable scopes are in `docs/verification/expected-differences.json`. An admitted correction permits only its documented difference envelope.

## Provenance repair: B1.5 -> B1.5p1

B1.5p1 repaired incorrect historical patch/preimage identity metadata discovered by VQ-1c without changing the intended five corrected source results. Historical B1.2-B1.5 remain audit records and are not exact executable oracles.

## B1.5p1 -> B1.10 summary

B1.6 admitted SWAP-009 with exact source provenance, direct constitutive verification, a representative full PDI run and hard legacy mass evidence. B1.7 admitted SWAP-010 and explicitly pinned the ordered B1.6 preimage because SWAP-009 and SWAP-010 share `WC_K_models_04_11.f90`. B1.8 admitted SWAP-013 as an input-validation-only difference. B1.9 admitted only the isolated SWAP-012 `prhead` inverse repair. B1.10 admitted SWAP-002 start-state/event-index initialization.

## B1.10 -> B1.11: SWAP-011 admission

SWAP-011 was historically qualified in the E5/E6/E7 audit line and reached `FIX_TESTED / READY_PATCH_UPSTREAM`. F-PE19 recovered the exact E7 package and patch, verified the B0 target identities byte-safely, and then reconciled the correction with the already admitted SWAP-009, SWAP-010 and SWAP-012 changes that overlap the current ordered B1 targets.

The immutable historical E7 patch identity remains separate from the ordered B1.10 admission transform:

```text
historical E7 patch SHA-256
9ccf4ec48462ea5f84684e3ee5c93b72bcb2b1c584dc3bdff47a4a0ec0621110

ordered B1.10 -> B1.11 patch SHA-256
1d3daab13d90036da3bc112ccd2c57ebcd56ac0970cce03d856cb6ede1249238
```

The ordered transform changes exactly:

```text
SWAP/MOD_MvG_functions.f90
SWAP/WC_K_models_04_11.f90
SWAP/MOD_RIA.f90
```

and leaves `SWAP/headcalc.f90` unchanged.

Ordered B1.10 target identities and B1.11 postimages are:

```text
MOD_MvG_functions.f90
  B1.10  4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1
  B1.11  6b65637866476581b283eb3d61c3aa0dfe4b51f84223f6eea571ac25ecac1104

WC_K_models_04_11.f90
  B1.10  7ca607b2bbf97e166a32ab8a529fc7f32af9949afb1e6eb518ddbf84e6f0169e
  B1.11  d6038f1c2e0f4d061738bb2a176398cd89b7da59310394a2c4049fd0b4214126

MOD_RIA.f90
  B1.10  a8695bbcb45ae4967686ae4dfbb7e365e91658a190165e86487ee9e5f1ffa9b3
  B1.11  673a76b899562e22a11dfc815b2e2d74d513d2ee21798aa85d52a631a35c9b3a
```

The complete canonical B0 distribution replay used the distribution SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360` and nested source archive SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`. It reproduced B1.10 exactly and then reproduced the frozen B1.11 identity exactly:

```text
members          63
source bytes      1,886,519
manifest SHA-256  24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2
```

The admitted difference is limited to correcting the implicit Richards conductivity derivative/Jacobian consistency for hydraulic models 3 and 5-12. Model 4 remains the standard MvG control. Physical retention/conductivity formulations, forcing, boundary definitions, mass requirements, solver policy and time-step policy are not changed by this admission.

## Audit findings waiting for B1 admission review

| Audit ID | State | Finding | Qualified correction status | Remaining gate |
| --- | --- | --- | --- | --- |
| `SWAP-003` | `CONFIRMED_UNFIXED` | tillage N-model 2 divides by `PCLAY` although zero is accepted | intended domain/targeted full regression not yet qualified | decide intended physical domain and add targeted/full tillage evidence |
| `SWAP-004` | `CONFIRMED_UNFIXED` | tillage type codes can index outside arrays allocated by event count | targeted input regression not yet qualified | isolate and test allocation/index validation before admission |

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
