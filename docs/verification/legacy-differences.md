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

`FIX_TESTED` does not automatically mean `ADMITTED_B1`. Admission requires exact patch provenance, canonical B0 preimage verification, qualification evidence and inclusion in the ordered B1 manifest.

## Admitted B0 -> B1 numerical/behavioural differences

| First snapshot | Audit ID | Classification | B0 behaviour | B1 correction | Qualification evidence |
| --- | --- | --- | --- | --- | --- |
| `B1.1` | `SWAP-001` | `ADMITTED_B1` code bug | whole fixed-length `VlMpDm1Cp` assigned from active slice `1:numnod`, non-conformable when extents differ | clear destination and copy only the active conformable slice | strict B0 5000/112 mismatch; VQ-1c3 full macropore smoke rejects B0 and completes B1.5p1 |
| `B1.2` | `SWAP-005` | `ADMITTED_B1` bounds/portability bug | compound `.AND.` may evaluate `cropstart(i+1)` before its bound guard | perform the `i < ifnd` guard before accessing `i+1` | source-bound signaling-NaN VQ-1c3 reproducer: B0 SIGFPE, B1.5p1 normal |
| `B1.3` | `SWAP-006` | `ADMITTED_B1` initialization/portability bug | meteo crop scan relies on an unused zero-initialized `cropstart` sentinel | iterate explicitly over loaded records `1:ifnd` | source-bound signaling-NaN VQ-1c3 reproducer: B0 enters unused record, B1.5p1 does not |
| `B1.4` | `SWAP-007` | `ADMITTED_B1` numerical robustness bug | tiny nonzero `fi_a` can overflow `fi/fi_a` and raise `SIGFPE` | only divide when the quotient is representable; otherwise use the existing large-`lnew` restart route | VQ-1c3 strict full grass case crashes B0 and completes B1.5p1; VQ-1c2 normal output unchanged |
| `B1.5` | `SWAP-008` | `ADMITTED_B1` Fortran correctness/portability bug | fallback `bandec`/`banbks` read incoming arrays declared `INTENT(OUT)` | declare consumed-and-overwritten arrays as `INTENT(INOUT)`; solver arithmetic unchanged | VQ-1c3 actual band-solver harness gives identical zero-residual solution while B1.5p1 restores a defined dummy contract |
| `B1.6` | `SWAP-009` | `ADMITTED_B1` PDI hydraulic code bug | four PDI conductivity functions pass `abs(h)` into a Kelvin vapor-conductivity relation that expects signed negative unsaturated pressure head, giving an incorrect vapor term that can grow dramatically in very dry soil | pass signed `h` at the four affected PDI callers; the shared Kelvin helper itself is unchanged | exact patch/preimage/corrected-target identities PASS; strict compiled PDI function gate PASS; representative full PDI production path PASS; hard unrounded legacy full-run mass gate PASS |

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

VQ qualified `B1.5p1` as the numerical/behavioural corrected-reference oracle used as the predecessor for B1.6.

## B1.5p1 -> B1.6: SWAP-009 admission

`B1.6` adds exactly one new correction, `SWAP-009`, to the VQ-qualified `B1.5p1` predecessor.

The admission evidence fixes both identity and behavior:

```text
SWAP-009 stored patch SHA-256
43e63c098868632da51a3dd1c2980e9af72d6ce2a3dabafadff76f2151256f66

canonical B0 target SHA-256
1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd

corrected target SHA-256
f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7
```

The strict compiled function-level gate shows that the old/corrected PDI vapor term follows the independent Kelvin-sign ratio, while water content and vapor-disabled conductivity are unchanged in the tested scope. The representative full SWAP PDI case produces small but real pressure-head/theta/flux differences with the same 57-by-2-iteration Newton route. Its predeclared `1e-6 cm` mass criterion passes with maximum absolute combined ponding/profile residuals of approximately `3.56e-8 cm` for both B0 and the corrected candidate.

The resulting deterministic B1.6 source-tree identity is:

```text
members          63
source bytes      1,860,085
manifest SHA-256  aad530d2b683aa25ed8d5ec87656fb3790b8d8f8faf6bff4b03d40a4c60136a0
```

This legacy mass evidence qualifies the B1 fix. It does not replace the future transaction-aware unrounded B2 mass-accounting contract.

## Audit findings waiting for B1 admission review

| Audit ID | State | Finding | Qualified correction status | Remaining admission gate |
| --- | --- | --- | --- | --- |
| `SWAP-011` | `PATCH_PAYLOAD_PENDING` | `dhconduc` uses a standard MvG conductivity derivative for hydraulic models whose implemented `K(h)` differs, producing an inconsistent implicit Richards Jacobian | E5/E6/E7 correction is `FIX_TESTED` / `READY_PATCH_UPSTREAM`; candidate dossier stored under `reference/swap-4.3.1/patches/SWAP-011/` | recover exact final E7 `fix.patch`, verify B0 preimages and patch bytes, then update B1 manifest |

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
