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

The five intended corrections remain unchanged in `B1.5p1`. Their machine-readable expected-difference scopes are in `docs/verification/expected-differences.json`.

## Provenance-only difference: B1.5 -> B1.5p1

`B1.5p1` is a `PROVENANCE_REPAIR`. It changes no intended corrected source behaviour relative to B1.5. It replaces invalid snapshot identity metadata with the exact stored patch hashes and canonical B0 target-member hashes discovered by the independent VQ-1c gate. Historical B1.2-B1.5 files remain unchanged as audit evidence.

VQ qualification is now complete on the VQ integration branch:

```text
VQ-1c1 exact identity/provenance              PASS
VQ-1c2 deterministic reconstruction           PASS
VQ-1c2 broad B0 -> B1 control edges           PASS
VQ-1c3 all five admitted correction gates     PASS
```

VQ therefore qualifies `B1.5p1` as the numerical/behavioural corrected-reference oracle for B2 regression. Until the VQ integration slice is merged, the reference-line manifest on `main` may still show its earlier pending status; that metadata lag is not a reason to rewrite historical snapshots.

This oracle status does not make rounded legacy `.BAL/.BLC` a machine-precision mass oracle and does not claim exhaustive coverage of every SWAP 4.3.1 option combination.

## Audit findings waiting for B1 admission review

| Audit ID | State | Finding | Qualified correction status | Remaining admission gate |
| --- | --- | --- | --- | --- |
| `SWAP-009` | `FIX_TESTED` candidate | four PDI conductivity functions pass `abs(h)` into a Kelvin vapor-conductivity relation that expects signed negative unsaturated pressure head, causing relative humidity greater than one and potentially very large dry-range conductivity error | exact minimal four-call-site patch, canonical B0 preimage, exact stored patch SHA and corrected-target SHA recorded under `reference/swap-4.3.1/patches/SWAP-009/`; existing hydraulic/theory tests and targeted PDI gate support the correction | complete the candidate's representative full PDI production-path regression, hard water-balance evidence and normal B1 admission procedure |
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
