# B1 corrected-reference snapshots

B1 is an ordered sequence of corrected SWAP 4.3.1 reference definitions. Each snapshot starts from the same byte-identified B0 source and adds only admitted, qualified bug fixes.

A published snapshot is never silently rewritten. If its provenance metadata later fail an exact identity gate, that snapshot remains in the audit history and a new provenance-repair snapshot is issued.

## Snapshot history

| Snapshot | Admitted patches | Exact-oracle status | Meaning |
| --- | --- | --- | --- |
| `B1.0-bootstrap` | none | historical | exact B0, no corrections |
| `B1.1` | `SWAP-001` | historical | first corrected reference |
| `B1.2` | `SWAP-001`, `SWAP-005` | **do not use as exact oracle** | historical patch-hash metadata mismatch found by VQ-1c |
| `B1.3` | + `SWAP-006` | **do not use as exact oracle** | inherits SWAP-005 mismatch and adds SWAP-006 mismatch |
| `B1.4` | + `SWAP-007` | **do not use as exact oracle** | additionally contains SWAP-007 patch-hash and B0-preimage provenance errors |
| `B1.5` | + `SWAP-008` | **do not use as exact oracle** | same five intended corrections, but inherits the earlier provenance failures |
| `B1.5p1` | same five patches as B1.5 | **pending independent VQ identity gate** | provenance-repaired replacement definition, no intended numerical change |

The exact definitions live under `reference/swap-4.3.1/snapshots/`.

## Admitted corrections

`SWAP-001` fixes the non-conformable macropore assignment. `SWAP-005` removes reliance on short-circuit evaluation in crop-calendar bounds checking. `SWAP-006` removes the implicit zero-initialization sentinel in the meteo crop loop. `SWAP-007` guards the oxygen-stress Newton update against an unrepresentable quotient while preserving the existing restart route. `SWAP-008` corrects the fallback band-solver dummy-argument contracts from `INTENT(OUT)` to `INTENT(INOUT)` without changing solver arithmetic.

These are still the intended five corrections in `B1.5p1`. The provenance repair does not add, remove or alter a physical/numerical correction.

## B1.5p1 provenance repair

VQ-1c independently checked the canonical B0 member identities and exact stored patch bytes. It found that the immutable B1.2-B1.5 metadata did not correctly identify several stored patch artifacts. For SWAP-007, the historical dossier also pinned a non-canonical B0 `oxygenstress.f90` hash.

`B1.5p1` therefore records:

- the exact stored patch SHA-256 for every admitted patch;
- canonical B0 target-member hashes;
- deterministic corrected-target hashes;
- a canonical-B0 verifier for SWAP-007;
- explicit provenance-repair status without rewriting B1.2-B1.5.

See `docs/verification/b1-5p1-provenance-repair.md` for the exact before/after identity table.

## Current use rule

`reference/swap-4.3.1/b1-manifest.yml` now points to `B1.5p1`, but it is marked `PENDING_VQ_IDENTITY_GATE`. Until the independent VQ gate reports PASS, B0 -> B1 numerical qualification remains blocked and B1.5p1 must not be described as a qualified exact executable oracle.

Candidate dossiers may still exist under `patches/` without being admitted. For example, SWAP-011 remains `PATCH_PAYLOAD_PENDING` and is not part of B1.5p1.
