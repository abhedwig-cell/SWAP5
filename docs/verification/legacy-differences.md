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
| `B1.1` | `SWAP-001` | `ADMITTED_B1` code bug | whole fixed-length `VlMpDm1Cp` assigned from active slice `1:numnod`, non-conformable when extents differ | clear destination and copy only the active conformable slice | strict B0 case fails with 5000/112 mismatch; patched macropore smoke completes |
| `B1.2` | `SWAP-005` | `ADMITTED_B1` bounds/portability bug | compound `.AND.` may evaluate `cropstart(i+1)` before its bound guard | perform the `i < ifnd` guard before accessing `i+1` | issue register `FIX_TESTED`; strict build evidence |
| `B1.3` | `SWAP-006` | `ADMITTED_B1` initialization/portability bug | meteo crop scan relies on an unused zero-initialized `cropstart` sentinel | iterate explicitly over loaded records `1:ifnd` | NaN-initialized reproducer exposes B0 dependence; patched build passes |
| `B1.4` | `SWAP-007` | `ADMITTED_B1` numerical robustness bug | tiny nonzero `fi_a` can overflow `fi/fi_a` and raise `SIGFPE` | only divide when the quotient is representable; otherwise use the existing large-`lnew` restart route | strict grass case crashes B0 and completes patched; normal output unchanged after timestamp normalization |
| `B1.5` | `SWAP-008` | `ADMITTED_B1` Fortran correctness/portability bug | fallback `bandec`/`banbks` read incoming arrays declared `INTENT(OUT)` | declare consumed-and-overwritten arrays as `INTENT(INOUT)`; solver arithmetic unchanged | issue register `FIX_TESTED`; correction compiled/tested in patch set |
| `B1.6` | `SWAP-009` | `ADMITTED_B1` PDI constitutive code bug | four PDI conductivity routes pass `abs(h)` into the Kelvin relative-humidity term, making `Hr > 1` for unsaturated suction | pass signed negative pressure head `h` to the existing Kelvin relation | issue register `FIX_TESTED`, certainty very high; hydraulic/theory checks; independent 20 °C sign check reproduces old/corrected vapor-term ratios about 1.16, 4.26 and 1.99e6 at -1e5, -1e6 and -1e7 cm |

The first five intended corrections are preserved unchanged through the provenance-repaired `B1.5p1`; `B1.6` is the first new numerical successor and adds only SWAP-009.

## Provenance-only difference: B1.5 -> B1.5p1

`B1.5p1` is a `PROVENANCE_REPAIR`. It changes no intended corrected source behaviour relative to B1.5. It replaces invalid snapshot identity metadata with the exact stored patch hashes and canonical B0 target-member hashes discovered by the independent VQ-1c gate. Historical B1.2-B1.5 files remain unchanged as audit evidence.

`B1.6` is based on the repaired B1.5p1 identities rather than on the historical mismatched snapshot metadata. The current manifest still marks exact executable-oracle use as `PENDING_VQ_IDENTITY_GATE`; therefore B0 -> B1 numerical equivalence claims remain blocked until VQ independently repins and passes the current snapshot.

## Audit findings waiting for B1 admission review

| Audit ID | State | Finding | Qualified correction status | Remaining admission gate |
| --- | --- | --- | --- | --- |
| `SWAP-011` | `PATCH_PAYLOAD_PENDING` | `dhconduc` uses a standard MvG conductivity derivative for hydraulic models whose implemented `K(h)` differs, producing an inconsistent implicit Richards Jacobian | E5/E6/E7 correction is `FIX_TESTED` / `READY_PATCH_UPSTREAM`; candidate dossier stored under `reference/swap-4.3.1/patches/SWAP-011/` | recover exact final E7 `fix.patch`, verify B0 preimages and patch bytes, then update B1 manifest |

Presence under `patches/` is not sufficient for admission. Only the ordered patch entries in the current manifest define B1 behaviour.

## Rule for SWAP 5 verification

For each SWAP 5 test result:

```text
if current B1 identity gate != PASS:
    reference equivalence is BLOCKED
elif B2 == pinned B1 within tolerance:
    reference equivalence passes
elif difference is an explicitly qualified SWAP 5 model change:
    evaluate against that change's acceptance criteria
else:
    fail as unexplained divergence
```

This prevents known bugs from being recreated for compatibility while preserving a complete explanation for every intentional departure from legacy SWAP 4.3.1.
