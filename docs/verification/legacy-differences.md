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

Machine-readable scopes are in `docs/verification/expected-differences.json`. An admitted correction permits only its documented difference envelope.

## Provenance repair: B1.5 -> B1.5p1

B1.5p1 repaired incorrect historical patch/preimage identity metadata discovered by VQ-1c without changing the intended five corrected source results. Historical B1.2-B1.5 remain audit records and are not exact executable oracles.

## B1.5p1 -> B1.9 summary

B1.6 admitted SWAP-009 with exact source provenance, direct constitutive verification, a representative full PDI run and hard legacy mass evidence. B1.7 admitted SWAP-010 and explicitly pinned the ordered B1.6 preimage because SWAP-009 and SWAP-010 share `WC_K_models_04_11.f90`. B1.8 admitted SWAP-013 as an input-validation-only difference. B1.9 admitted only the isolated SWAP-012 `prhead` inverse repair; historical SWAP-011 `dhconduc` content remained excluded.

## B1.9 -> B1.10: SWAP-002 admission

`SWAP/tillage.f90` is unchanged by B1.1-B1.9, so canonical B0 and ordered B1.9 preimages are identical:

```text
canonical B0 / ordered B1.9 tillage.f90
731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486

stored SWAP-002 patch
80e12cd4e9f47c192bd6c7d5ee7d460c473b3a2b29a5a553e8c35cf0b90b5c13

corrected target
eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3
```

The legacy interval condition compares `t1900` against `Date_tillage(i-1)` as both lower and upper bound and therefore can never select a run start between events. The corrected semantics are: `iTill` is the next event still to execute; if historical events precede the simulation start, their latest parameter state is loaded for consolidation.

A fresh strict GNU Fortran source-bound gate checks before-first, exact-first, between-events, exact-second, after-last and unsorted-date cases. B0 passes 3/6; the isolated candidate passes 6/6 and loads the expected previous event. The patch contains no SWAP-003 `PCLAY` guard and no SWAP-004 tillage type-index changes.

Deterministic B1.10 identity:

```text
members          63
source bytes      1,863,575
manifest SHA-256  2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1
```

The expected difference is limited to tillage start-state/event-index initialization and consequences attributable to that corrected state. No tillage constitutive formula, solver policy or mass tolerance changes. Because B0 supplies no standard complete tillage scenario, this does not claim exhaustive qualification of all tillage interactions.

## Audit findings waiting for B1 admission review

| Audit ID | State | Finding | Qualified correction status | Remaining gate |
| --- | --- | --- | --- | --- |
| `SWAP-011` | `PATCH_PAYLOAD_PENDING` | `dhconduc` derivative inconsistent with implemented `K(h)` for several models | E5/E6/E7 `FIX_TESTED` / `READY_PATCH_UPSTREAM` | recover exact final E7 patch and verify exact provenance |
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
