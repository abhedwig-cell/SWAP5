# B1 corrected-reference snapshots

B1 is an ordered, immutable sequence of corrected SWAP 4.3.1 reference definitions. Each snapshot starts from the same byte-identified B0 source and adds only admitted qualified bug fixes.

## Snapshot history

| Snapshot | Definition | Admitted patches | Meaning |
| --- | --- | --- | --- |
| `B1.0-bootstrap` | `reference/swap-4.3.1/snapshots/B1.0-bootstrap.yml` | none | exact B0, no corrections |
| `B1.1` | `reference/swap-4.3.1/snapshots/B1.1.yml` | `SWAP-001` | first corrected reference |
| `B1.2` | `reference/swap-4.3.1/snapshots/B1.2.yml` | `SWAP-001`, `SWAP-005` | adds crop-calendar bounds/portability correction |
| `B1.3` | `reference/swap-4.3.1/snapshots/B1.3.yml` | `SWAP-001`, `SWAP-005`, `SWAP-006` | removes meteo crop-calendar sentinel/initialization dependence |
| `B1.4` | `reference/swap-4.3.1/snapshots/B1.4.yml` | `SWAP-001`, `SWAP-005`, `SWAP-006`, `SWAP-007` | adds oxygenstress Newton-overflow guard |
| `B1.5` | `reference/swap-4.3.1/snapshots/B1.5.yml` | `SWAP-001`, `SWAP-005`, `SWAP-006`, `SWAP-007`, `SWAP-008` | corrects fallback band-solver dummy-argument intent |

## B1.1: SWAP-001

SWAP-001 corrects a non-conformable macropore array assignment. B0 assigns a fixed-length destination array from a shorter `1:numnod` source slice. The corrected reference initializes the destination and copies only the conformable active slice.

## B1.2: SWAP-005

SWAP-005 removes reliance on short-circuit evaluation in the crop-calendar sequence check. The physical crop-sequence criterion is unchanged.

## B1.3: SWAP-006

SWAP-006 removes an implicit sentinel based on zero-initialized unused `cropstart` elements and limits the dynamic-crop meteo loop to the loaded record count `ifnd`.

## B1.4: SWAP-007

SWAP-007 prevents overflow in an oxygen-stress Newton update when `fi_a` is nonzero but too small for a representable `fi/fi_a`. The original update remains unchanged when representable.

## B1.5: SWAP-008

SWAP-008 corrects the Fortran dummy-argument contracts of the rare fallback band solver. `bandec` consumes and overwrites `a`; `banbks` consumes and overwrites `b`. B0 declared those arrays `INTENT(OUT)`, which makes their incoming values undefined by language semantics even though the routines immediately read them. B1.5 changes only those declarations to `INTENT(INOUT)`.

No solver arithmetic, pivoting, factorization, substitution or fallback-selection logic is changed. The issue register records the correction as `FIX_TESTED`, certainty very high, compiled/tested in the patch set. The exact B0 preimage, isolated patch SHA-256, deterministic corrected-file SHA-256 and byte-safe verifier are stored in the SWAP-008 patch dossier.

## Candidate versus admitted

Candidate dossiers may be prepared before their exact patch is ready. SWAP-011 remains technically qualified but has `PATCH_PAYLOAD_PENDING` provenance status and therefore does not appear in B1.5.

Only the ordered patch entries in `reference/swap-4.3.1/b1-manifest.yml` define the current B1 behaviour.
