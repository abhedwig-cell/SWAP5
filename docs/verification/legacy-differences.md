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

| B1 snapshot | Audit ID | Classification | B0 behaviour | B1 correction | Qualification evidence | B1 identity |
| --- | --- | --- | --- | --- | --- | --- |
| `B1.0-bootstrap` | _none_ | bootstrap | exact B0 | none | B0 source-integrity gate | empty ordered patch list |
| `B1.1` | `SWAP-001` | `ADMITTED_B1` code bug | whole fixed-length `VlMpDm1Cp` assigned from active slice `VlMpDmCp(1,1:numnod)`, non-conformable when extents differ | clear destination and copy only `1:numnod` active slice | original strict case fails with 5000/112 mismatch; patched macropore smoke run completes; byte-exact B0 preimage and deterministic patched-file SHA verified | `reference/swap-4.3.1/snapshots/B1.1.yml` |
| `B1.2` | `SWAP-005` | `ADMITTED_B1` bounds/portability bug | compound `.AND.` may evaluate `cropstart(i+1)` before the `i < ifnd` guard | enforce `i < ifnd` in outer control flow, then evaluate the unchanged crop-sequence test | issue register `FIX_TESTED`, certainty very high; strict build passes; exact B0 preimage and isolated patch recorded | `reference/swap-4.3.1/snapshots/B1.2.yml` |
| `B1.3` | `SWAP-006` | `ADMITTED_B1` initialization/portability bug | meteo crop-calendar scan runs until an unused `cropstart` entry acts as a zero sentinel | iterate explicitly over loaded records `1:ifnd`, retaining existing date exits and crop-type logic | issue register `FIX_TESTED`, certainty high; NaN-initialized test exposes B0 dependence and patched build passes; exact B0 preimage and isolated patch recorded | `reference/swap-4.3.1/snapshots/B1.3.yml` |
| `B1.4` | `SWAP-007` | `ADMITTED_B1` numerical robustness bug | oxygenstress Newton update divides by any nonzero `fi_a`; tiny derivatives can overflow `fi/fi_a` and raise `SIGFPE` | require the quotient to be representable; otherwise set large `lnew` so the existing restart logic handles the step | strict grass case crashes B0 at oxygenstress line 849 and completes patched; normal result output is identical after timestamp normalization; byte-exact preimage and corrected-file SHA verified | `reference/swap-4.3.1/snapshots/B1.4.yml` |
| `B1.5` | `SWAP-008` | `ADMITTED_B1` Fortran correctness/portability bug | fallback `bandec`/`banbks` declare arrays `INTENT(OUT)` although their incoming values are immediately read | declare only those consumed-and-overwritten arrays as `INTENT(INOUT)`; arithmetic and solver algorithm unchanged | issue register `FIX_TESTED`, certainty very high; correction compiled/tested in patch set; exact B0 preimage and corrected-file SHA verified | `reference/swap-4.3.1/snapshots/B1.5.yml` |

`B1.5` is the current corrected snapshot and contains the ordered patch set `SWAP-001`, `SWAP-005`, `SWAP-006`, `SWAP-007`, `SWAP-008`.

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
