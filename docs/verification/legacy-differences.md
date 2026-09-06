# Legacy difference ledger

## Purpose

This ledger is the authoritative map of intentional numerical or behavioural differences between the immutable B0 audit baseline and the corrected B1 reference line.

A SWAP 5 difference from B0 is acceptable only when it is either:

- explicitly listed here as an admitted B1 correction; or
- separately qualified as an intentional SWAP 5 model/architecture change.

Unexplained differences are verification failures until classified.

## Admission states

| State | Meaning |
| --- | --- |
| `OBSERVED` | discrepancy detected; cause not yet established |
| `BUG_CONFIRMED` | legacy implementation defect demonstrated |
| `FIX_TESTED` | candidate legacy repair has passed its defined qualification |
| `PATCH_PAYLOAD_PENDING` | fix is qualified, but the exact qualified patch artifact has not yet passed B1 provenance checks |
| `ADMITTED_B1` | exact qualified patch is included in an immutable B1 snapshot definition |
| `MODEL_CHANGE` | intentional model development; never silently folded into B1 |
| `DOC_ONLY` | documentation correction without B1 numerical change |

`FIX_TESTED` does not automatically mean `ADMITTED_B1`. Admission requires exact patch provenance, B0 preimage verification and inclusion in the ordered `reference/swap-4.3.1/b1-manifest.yml` patch list.

## Published B1 differences

`B1.0-bootstrap` is defined in Git and contains no corrections. It is therefore numerically identical to B0 by definition.

| B1 snapshot | Audit ID | Classification | B0 behaviour | B1 correction | Qualification evidence | B1 identity |
| --- | --- | --- | --- | --- | --- | --- |
| `B1.0-bootstrap` | _none_ | bootstrap | exact B0 | none | B0 source-integrity gate | empty ordered patch list |

No numerical B0-to-B1 difference has yet been admitted.

## Audit findings waiting for B1 admission review

| Audit ID | State | Finding | Qualified correction status | Remaining admission gate |
| --- | --- | --- | --- | --- |
| `SWAP-011` | `PATCH_PAYLOAD_PENDING` | `dhconduc` uses a standard MvG conductivity derivative for hydraulic models whose implemented `K(h)` differs, producing an inconsistent implicit Richards Jacobian | E5/E6/E7 correction is `FIX_TESTED` / `READY_PATCH_UPSTREAM`; candidate dossier stored under `reference/swap-4.3.1/patches/SWAP-011/` | recover exact final E7 `fix.patch`, verify B0 preimages and patch bytes, then update B1 manifest |

The candidate directory may exist before admission. Presence under `patches/` is not sufficient: only IDs in the ordered B1 manifest define the corrected reference.

When a fix is admitted, record at least:

```text
Audit ID
B1 snapshot first containing fix
B1 manifest/commit identity
B0 reproduction
exact patch artifact SHA-256
verified B0 preimage identities
qualification/test evidence
expected numerical/behavioural difference
scope known to remain unchanged
```

## Rule for SWAP 5 verification

For each SWAP 5 test result:

```text
if B2 == pinned B1 within tolerance:
    reference equivalence passes
elif difference is an explicitly qualified SWAP 5 model change:
    evaluate against that change's acceptance criteria
else:
    fail as unexplained divergence
```

This prevents known bugs from being recreated for compatibility while preserving a complete explanation for every intentional departure from legacy SWAP 4.3.1.
