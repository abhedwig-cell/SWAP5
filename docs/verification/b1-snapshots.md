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
| `B1.6` | B1.5p1 + `SWAP-009` | **pending independent VQ identity gate** | first new numerical successor to the repaired lineage; adds the PDI vapor-conductivity head-sign correction |

The exact definitions live under `reference/swap-4.3.1/snapshots/`.

## Admitted corrections through B1.5p1

`SWAP-001` fixes the non-conformable macropore assignment. `SWAP-005` removes reliance on short-circuit evaluation in crop-calendar bounds checking. `SWAP-006` removes the implicit zero-initialization sentinel in the meteo crop loop. `SWAP-007` guards the oxygen-stress Newton update against an unrepresentable quotient while preserving the existing restart route. `SWAP-008` corrects the fallback band-solver dummy-argument contracts from `INTENT(OUT)` to `INTENT(INOUT)` without changing solver arithmetic.

These are the five intended corrections in `B1.5p1`. The provenance repair does not add, remove or alter a physical/numerical correction.

## B1.5p1 provenance repair

VQ-1c independently checked the canonical B0 member identities and exact stored patch bytes. It found that the immutable B1.2-B1.5 metadata did not correctly identify several stored patch artifacts. For SWAP-007, the historical dossier also pinned a non-canonical B0 `oxygenstress.f90` hash.

`B1.5p1` therefore records exact stored patch SHA-256 values, canonical B0 target-member hashes, deterministic corrected-target hashes and explicit provenance-repair status without rewriting B1.2-B1.5. See `docs/verification/b1-5p1-provenance-repair.md` for the exact before/after identity table.

## B1.6: SWAP-009 PDI vapor sign

`SWAP-009` affects four PDI conductivity functions in `WC_K_models_04_11.f90`. B0 passes `abs(h)` to `Kvap_func`, while `Kvap_func` itself evaluates the Kelvin factor as:

```fortran
Hr = dexp(h/100.0d0*MgRT)
```

For unsaturated pressure head `h < 0`, the signed relation yields `0 < Hr < 1`. Passing `abs(h)` reverses the exponent sign and gives `Hr > 1`. B1.6 changes only those four calls so the existing Kelvin implementation receives signed `h`.

The audit register marks SWAP-009 `FIX_TESTED`, certainty very high, severity high, with hydraulic tests and theory cross-check. An independent no-compiler algebraic check reproduces the audit-note old/corrected vapor-term ratios at 20 °C: approximately 1.16 at `-1e5 cm`, 4.26 at `-1e6 cm` and `1.99e6` at `-1e7 cm`.

B1.6 uses the exact repaired patch identities from B1.5p1 for SWAP-001/005/006/007/008 and adds an exact isolated SWAP-009 patch with canonical B0 preimage and deterministic corrected-target hash.

## Current use rule

`reference/swap-4.3.1/b1-manifest.yml` points to `B1.6`, but its exact executable-oracle status remains `PENDING_VQ_IDENTITY_GATE`. Until the independent VQ gate reports PASS, B0 -> B1 numerical qualification remains blocked and B1.6 must not be described as a qualified exact executable oracle.

Candidate dossiers may still exist under `patches/` without being admitted. SWAP-011 remains `PATCH_PAYLOAD_PENDING` and is not part of B1.6.
