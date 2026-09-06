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
| `B1.9` | `SWAP-012` | hydraulic inverse algorithm bug | models 3 and 5-12 fall through to unrelated default-MvG `prhead` inverse | numerically invert selected retention relation; retain model-4 analytical control | D2 22,240-point gate + isolated actual-source 600-point gate |
| `B1.10` | `SWAP-002` | tillage control-flow/state-initialization bug | impossible interval test can retain wrong next-event pointer when a run starts after first event | choose first event on/after start and load most recent previous tillage parameter state | historical semantic test + strict compiled 3/6 -> 6/6 gate |
| `B1.11` | `SWAP-004` | tillage indexing/input-consistency bug | type code can index outside lookup arrays sized by event count | size/map lookup by type-code domain and reject unresolved event types | strict B0 bounds reproducer + focused candidate 4/4 gate |

Machine-readable scopes are in `docs/verification/expected-differences.json`. An admitted correction permits only its documented difference envelope.

## Provenance repair: B1.5 -> B1.5p1

B1.5p1 repaired incorrect historical patch/preimage identity metadata discovered by VQ-1c without changing the intended five corrected source results. Historical B1.2-B1.5 remain audit records and are not exact executable oracles.

## B1.5p1 -> B1.10 summary

B1.6 admitted SWAP-009 with exact source provenance, direct constitutive verification, a representative full PDI run and hard legacy mass evidence. B1.7 admitted SWAP-010 and pinned the ordered B1.6 preimage because SWAP-009 and SWAP-010 share `WC_K_models_04_11.f90`. B1.8 admitted SWAP-013 as an input-validation-only difference. B1.9 admitted only the isolated SWAP-012 `prhead` inverse repair; historical SWAP-011 `dhconduc` content remained excluded. B1.10 admitted SWAP-002 and established the corrected tillage start-event state semantics.

## B1.10 -> B1.11: SWAP-004 admission

SWAP-004 also targets `SWAP/tillage.f90`, so both canonical B0 provenance and the exact ordered B1.10 preimage are mandatory:

```text
canonical B0 tillage.f90
731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486

ordered B1.10 tillage.f90
eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3

stored SWAP-004 patch
0a1b52cb018ebfc6aa11da2e04d52e858addfa5810c69b0fe078fd5f8bed8818

corrected target
41a42be1f55e533843b7ecc115f9de2fbd7bc4c08515cb58a9bf6efb0479bede
```

Legacy `TYPE_TILLAGE` is used as an index into `iTT1/iTT2`, while those arrays are allocated by `Ntill`. A represented type code greater than the event count can therefore be accepted and later address outside the arrays. The B0 sparse reproducer with `Ntill=1` and type code 3 fails under strict bounds checking. The isolated correction allocates/maps over `1:tmax` and validates that every event type resolves to an `ITYPE_TILLAGE` record.

Focused candidate qualification passes 4/4 cases: the dense legacy-valid mapping remains identical, represented type codes above `Ntill` are safe, represented non-contiguous types are safe, and a missing mapping record is rejected. SWAP-003 is absent from the patch.

Deterministic B1.11 identity:

```text
members          63
source bytes      1,863,998
manifest SHA-256  a0f4adc5d0a126e74bfb68b33c00ba665e80b91e926d8bf356adaf97a5d304d6
```

The expected difference is restricted to the tillage type lookup domain and invalid-mapping rejection. Dense valid legacy mappings remain unchanged. No tillage constitutive formula, solver policy, timestep policy, water-balance equation or mass tolerance changes. Because no standard complete B0 tillage case exists, the admission does not claim exhaustive end-to-end tillage qualification.

## Audit findings waiting for B1 admission review

| Audit ID | State | Finding | Qualified correction status | Remaining gate |
| --- | --- | --- | --- | --- |
| `SWAP-011` | `PATCH_PAYLOAD_PENDING` | `dhconduc` derivative inconsistent with implemented `K(h)` for several models | E5/E6/E7 `FIX_TESTED` / `READY_PATCH_UPSTREAM` | recover exact final E7 patch and verify exact provenance |
| `SWAP-003` | `CONFIRMED_UNFIXED` | tillage N-model 2 divides by `PCLAY` although zero is accepted | intended domain/targeted full regression not yet qualified | decide intended physical domain and add targeted/full tillage evidence |

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
