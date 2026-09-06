# B1 corrected-reference snapshots

B1 is an ordered, immutable sequence of corrected SWAP 4.3.1 reference definitions. Each snapshot starts from the same byte-identified B0 source and adds only admitted qualified bug fixes.

## Snapshot history

| Snapshot | Definition | Admitted patches | Meaning |
| --- | --- | --- | --- |
| `B1.0-bootstrap` | `reference/swap-4.3.1/snapshots/B1.0-bootstrap.yml` | none | exact B0, no corrections |
| `B1.1` | `reference/swap-4.3.1/snapshots/B1.1.yml` | `SWAP-001` | first corrected reference |

## B1.1: SWAP-001

SWAP-001 corrects a non-conformable macropore array assignment. B0 assigns a fixed-length destination array from a shorter `1:numnod` source slice. The corrected reference initializes the destination and copies only the conformable active slice.

The B1 admission records:

- exact B0 `macropore.f90` SHA-256;
- exact minimal patch SHA-256;
- deterministic patched-file SHA-256;
- byte-safe application/verification helper;
- strict-run audit evidence reproducing the original 5000/112 shape failure and normal completion after the correction.

This is a code-correctness repair, not model development.

## Candidate versus admitted

Candidate dossiers may be prepared before their exact patch is ready. For example, SWAP-011 is technically qualified but still has `PATCH_PAYLOAD_PENDING` provenance status. It therefore does not appear in B1.1.

Only the ordered patch entries in `reference/swap-4.3.1/b1-manifest.yml` define the current B1 behaviour.
