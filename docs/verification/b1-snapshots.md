# B1 corrected-reference snapshots

B1 is an ordered, immutable sequence of corrected SWAP 4.3.1 reference definitions. Each snapshot starts from the same byte-identified B0 source and adds only admitted qualified bug fixes.

## Snapshot history

| Snapshot | Definition | Admitted patches | Meaning |
| --- | --- | --- | --- |
| `B1.0-bootstrap` | `reference/swap-4.3.1/snapshots/B1.0-bootstrap.yml` | none | exact B0, no corrections |
| `B1.1` | `reference/swap-4.3.1/snapshots/B1.1.yml` | `SWAP-001` | first corrected reference |
| `B1.2` | `reference/swap-4.3.1/snapshots/B1.2.yml` | `SWAP-001`, `SWAP-005` | adds crop-calendar bounds/portability correction |

## B1.1: SWAP-001

SWAP-001 corrects a non-conformable macropore array assignment. B0 assigns a fixed-length destination array from a shorter `1:numnod` source slice. The corrected reference initializes the destination and copies only the conformable active slice.

The B1 admission records exact B0 and patch identities, a deterministic corrected-file SHA-256, a byte-safe application/verification helper and strict-run audit evidence reproducing the original 5000/112 shape failure and normal completion after correction.

## B1.2: SWAP-005

SWAP-005 removes reliance on short-circuit evaluation in the crop-calendar sequence check. Fortran does not guarantee that the `i < ifnd` operand is evaluated before `cropstart(i+1)`. B1.2 therefore makes the bound a separate outer `if` before accessing the next crop entry.

The physical crop-sequence criterion is unchanged. The admission records the exact B0 `MOD_cropdevelopment.f90` identity, the isolated minimal patch identity, a preimage-checking application helper and the existing `FIX_TESTED` strict-build evidence.

## Candidate versus admitted

Candidate dossiers may be prepared before their exact patch is ready. For example, SWAP-011 is technically qualified but still has `PATCH_PAYLOAD_PENDING` provenance status. It therefore does not appear in B1.2.

Only the ordered patch entries in `reference/swap-4.3.1/b1-manifest.yml` define the current B1 behaviour.
