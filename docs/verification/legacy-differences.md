# Legacy difference ledger

## Purpose

This ledger is the authoritative map of intentional numerical or behavioural differences between the immutable B0 audit baseline and the corrected B1 reference line.

A SWAP 5 difference from B0 is acceptable only when it is either explicitly listed here as an admitted B1 correction or separately qualified as an intentional SWAP 5 model/architecture change. Unexplained differences are verification failures until classified.

## Admission states

| State | Meaning |
| --- | --- |
| `OBSERVED` | discrepancy detected; cause not yet established |
| `BUG_CONFIRMED` | legacy implementation defect demonstrated |
| `FIX_TESTED` | candidate legacy repair has passed its defined qualification |
| `PATCH_PAYLOAD_PENDING` | fix is qualified, but the exact qualified patch artifact has not yet passed B1 provenance checks |
| `ADMITTED_B1` | qualified correction is included in the current corrected-reference patch set |
| `PROVENANCE_REPAIR` | identity metadata repaired without an intended numerical/model change |
| `MODEL_CHANGE` | intentional model development; never silently folded into B1 |
| `DOC_ONLY` | documentation correction without B1 numerical change |

`FIX_TESTED` does not automatically mean `ADMITTED_B1`. Admission requires exact patch provenance, canonical B0 preimage verification, ordered preimage verification when patches share a target, qualification evidence and inclusion in the ordered B1 manifest.

## Admitted B0 -> B1 numerical/behavioural differences

| First snapshot | Audit ID | Classification | B0 behaviour | B1 correction | Qualification evidence |
| --- | --- | --- | --- | --- | --- |
| `B1.1` | `SWAP-001` | `ADMITTED_B1` code bug | whole fixed-length `VlMpDm1Cp` assigned from active slice `1:numnod`, non-conformable when extents differ | clear destination and copy only the active conformable slice | strict B0 5000/112 mismatch; VQ-1c3 full macropore smoke rejects B0 and completes corrected reference |
| `B1.2` | `SWAP-005` | `ADMITTED_B1` bounds/portability bug | compound `.AND.` may evaluate `cropstart(i+1)` before its bound guard | perform the `i < ifnd` guard before accessing `i+1` | source-bound signaling-NaN reproducer: B0 SIGFPE, corrected reference normal |
| `B1.3` | `SWAP-006` | `ADMITTED_B1` initialization/portability bug | meteo crop scan relies on an unused zero-initialized `cropstart` sentinel | iterate explicitly over loaded records `1:ifnd` | source-bound signaling-NaN reproducer: B0 enters unused record, corrected reference does not |
| `B1.4` | `SWAP-007` | `ADMITTED_B1` numerical robustness bug | tiny nonzero `fi_a` can overflow `fi/fi_a` and raise `SIGFPE` | only divide when the quotient is representable; otherwise use the existing large-`lnew` restart route | strict full grass case crashes B0 and completes corrected reference; ordinary output unchanged |
| `B1.5` | `SWAP-008` | `ADMITTED_B1` Fortran correctness/portability bug | fallback `bandec`/`banbks` read incoming arrays declared `INTENT(OUT)` | declare consumed-and-overwritten arrays as `INTENT(INOUT)`; solver arithmetic unchanged | actual band-solver harness gives identical zero-residual solution while corrected reference restores a defined dummy contract |
| `B1.6` | `SWAP-009` | `ADMITTED_B1` PDI hydraulic code bug | four PDI conductivity functions pass `abs(h)` into a Kelvin vapor-conductivity relation that expects signed negative unsaturated pressure head | pass signed `h` at the four affected PDI callers | strict PDI function gate, full PDI production path and hard unrounded legacy mass gate PASS |
| `B1.7` | `SWAP-010` | `ADMITTED_B1` model-7 hydraulic algebra bug | `C_MvG_2_s` is not the derivative of the implemented scaled-bimodal retention curve | use the same weighted common denominator as the implemented retention relation | source-bound derivative gate 784/1000 -> 0/1000 failures; sensitive full model-7 run restores the fixed `1e-6 cm` legacy mass criterion |
| `B1.8` | `SWAP-013` | `ADMITTED_B1` PDI input-domain bug | scalar ranges allow PDI `HA=0` and `HA>=H0` after magnitude conversion, although downstream formulas use `log10(HA)` and a `log10(HA)-log10(H0)` denominator | reject PDI models 8–11 unless `0 < HA < H0` after magnitude conversion | historical patch compile/hydraulic evidence PASS; source-bound compiled 9-case guard gate PASS; exact patch/preimage/corrected-target identities PASS |

Machine-readable expected-difference scopes are in `docs/verification/expected-differences.json`. An admitted correction permits only its documented difference envelope; it does not make arbitrary B0/B1 divergence acceptable.

## Provenance-only difference: B1.5 -> B1.5p1

`B1.5p1` is a `PROVENANCE_REPAIR`. It changes no intended corrected source behaviour relative to B1.5. It replaces invalid snapshot identity metadata with the exact stored patch hashes and canonical B0 target-member hashes discovered by the independent VQ-1c gate. Historical B1.2-B1.5 files remain unchanged as audit evidence.

The integrated VQ qualification establishes:

```text
VQ-1c1 exact identity/provenance              PASS
VQ-1c2 deterministic reconstruction           PASS
VQ-1c2 broad B0 -> B1 control edges           PASS
VQ-1c3 all five predecessor correction gates  PASS
```

## B1.5p1 -> B1.6: SWAP-009 admission

B1.6 added the PDI Kelvin-sign correction with exact source provenance, direct constitutive verification, a representative full PDI run and an unrounded legacy mass gate. Its deterministic source manifest is:

```text
aad530d2b683aa25ed8d5ec87656fb3790b8d8f8faf6bff4b03d40a4c60136a0
```

## B1.6 -> B1.7: SWAP-010 admission

B1.7 added the model-7 capacity derivative correction. Because SWAP-009 and SWAP-010 share `WC_K_models_04_11.f90`, the ordered B1.6 preimage is explicitly pinned. The direct derivative gate gives 784/1000 inconsistent B1.6 points versus 0/1000 after correction. In a sensitive full model-7 run, B1.6 reaches an unrounded diagnostic residual of about `1.58e-6 cm` and creates `result.dwb`; the corrected candidate reaches about `1.00e-8 cm` with no `.dwb`, under the unchanged predeclared `1e-6 cm` criterion.

Deterministic B1.7 source-tree identity:

```text
members          63
source bytes      1,860,091
manifest SHA-256  62939097cfcdb59f8fe8c9161356fc703d7c54d6dd61ab3c31b19c2cfea6a5ba
```

## B1.7 -> B1.8: SWAP-013 admission

SWAP-013 changes input validation only. `readswap.f90` was unchanged by all earlier admitted B1 patches, so the canonical B0 and ordered B1.7 preimage identities are equal and explicitly checked:

```text
canonical B0 / ordered B1.7 readswap.f90
3ab42ae4ad9a76d96b01d90b173cf821a9add8514620a965bf31eaf874405cf2

SWAP-013 stored patch SHA-256
066c1c1aba8f32cb3a9aab3d17f1900b0ba8a28f43173d80461c91fb1a8f25f3

B1.8 corrected readswap.f90
e2ddee83afde65d5c10af561c8271c2cd6f23065d431160bf1467d5ebd18768c
```

The guard executes after the existing negative-input-to-positive-magnitude conversion and before APAR is read. It is limited to hydraulic models 8–11 and enforces `0 < HA < H0` on those magnitudes. A fresh strict GNU Fortran predicate gate passes 9/9 cases: four valid PDI inputs accepted, `HA=0`, `HA=H0` and `HA>H0` rejected, and model 7/12 controls unaffected.

This is intentionally not a numerical-trajectory difference for valid runs. The accepted constitutive functions, time integration, solver policy and water-balance equations remain byte-identical to B1.7. The only admitted behaviour change is earlier deterministic rejection of mathematically singular PDI input combinations. A rejected invalid configuration has no accepted physical interval for which a mass-balance concession could be made.

Deterministic B1.8 source-tree identity:

```text
members          63
source bytes      1,860,493
manifest SHA-256  e32395a6dc1c4ad0caa551739c411669f0b51117dcf68ba719cad75a82fbdcae
```

## Audit findings waiting for B1 admission review

| Audit ID | State | Finding | Qualified correction status | Remaining admission gate |
| --- | --- | --- | --- | --- |
| `SWAP-011` | `PATCH_PAYLOAD_PENDING` | `dhconduc` uses a standard MvG conductivity derivative for hydraulic models whose implemented `K(h)` differs, producing an inconsistent implicit Richards Jacobian | E5/E6/E7 correction is `FIX_TESTED` / `READY_PATCH_UPSTREAM` | recover exact final E7 `fix.patch`, verify B0 preimages and patch bytes, then update B1 manifest |

Presence under `patches/` is not sufficient for admission. Only the ordered patch entries in the current manifest define B1 behaviour.

## Rule for SWAP 5 verification

For each SWAP 5 test result:

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
