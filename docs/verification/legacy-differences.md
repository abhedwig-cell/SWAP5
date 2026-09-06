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
| `ADMITTED_B1` | exact patch commit is part of the corrected B1 history |
| `MODEL_CHANGE` | intentional model development; never silently folded into B1 |
| `DOC_ONLY` | documentation correction without B1 numerical change |

`FIX_TESTED` does not automatically mean `ADMITTED_B1`. Admission requires an exact B1 commit in the corrected-reference repository.

## Published B1 differences

No B1 snapshot has yet been formally published in Git. This table remains empty until the separate corrected-reference repository is seeded from the exact B0 source and qualified patches are admitted one by one.

| B1 snapshot | Audit ID | Classification | B0 behaviour | B1 correction | Qualification evidence | B1 commit |
| --- | --- | --- | --- | --- | --- | --- |
| _none yet_ |  |  |  |  |  |  |

## Audit findings waiting for B1 admission review

The SWAP 4.3.1 audit already contains confirmed and tested defects. Their existing audit status remains authoritative until each exact patch is reconstructed on B0 and admitted to B1. This ledger deliberately does not pre-empt that source-level admission decision.

When a fix is admitted, record at least:

```text
Audit ID
B1 tag first containing fix
B1 commit SHA
B0 reproduction
minimal patch identity
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
