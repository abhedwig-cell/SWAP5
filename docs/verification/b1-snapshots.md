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
| `B1.5p1` | same five patches as B1.5 | qualified predecessor oracle | provenance-repaired definition; VQ identity, reconstruction, broad controls and all five targeted gates PASS |
| `B1.6` | B1.5p1 + `SWAP-009` | **current qualified corrected reference** | adds the qualified PDI Kelvin-sign vapor-conductivity correction |

The exact definitions live under `reference/swap-4.3.1/snapshots/`.

## Admitted corrections through B1.6

`SWAP-001` fixes the non-conformable macropore assignment. `SWAP-005` removes reliance on short-circuit evaluation in crop-calendar bounds checking. `SWAP-006` removes the implicit zero-initialization sentinel in the meteo crop loop. `SWAP-007` guards the oxygen-stress Newton update against an unrepresentable quotient while preserving the existing restart route. `SWAP-008` corrects the fallback band-solver dummy-argument contracts from `INTENT(OUT)` to `INTENT(INOUT)` without changing solver arithmetic.

`SWAP-009`, first admitted in `B1.6`, corrects four PDI conductivity callers that supplied `abs(h)` to a Kelvin vapor-conductivity helper whose implemented relation expects signed negative unsaturated pressure head. The correction passes signed `h`; the Kelvin helper itself is not changed.

## B1.5p1 provenance repair and qualification

VQ-1c independently checked the canonical B0 member identities and exact stored patch bytes. It found that immutable B1.2-B1.5 metadata did not correctly identify several stored patch artifacts. For SWAP-007, the historical dossier also pinned a non-canonical B0 `oxygenstress.f90` hash.

`B1.5p1` repaired the provenance without changing the intended five corrected source results. Subsequent VQ qualification established:

```text
exact snapshot/provenance identity             PASS
deterministic source reconstruction            PASS
all corrected-target SHA-256 gates             PASS
broad B0 -> B1 control edges                   PASS
all five correction-triggering gates           PASS
```

`B1.5p1` is therefore the qualified predecessor from which `B1.6` is derived.

## B1.6: SWAP-009 admission

SWAP-009 passed all required admission layers:

```text
exact patch and canonical B0 preimage          PASS
corrected target identity                      PASS
strict compiled PDI function-level gate        PASS
representative full PDI production-path gate   PASS
hard unrounded legacy full-run mass gate       PASS
expected-difference registration               PASS
```

The representative full run retains the same 57 x 2-iteration Newton route for B0 and corrected execution while producing the expected small pressure-head/theta/flux changes. The predeclared `1e-6 cm` mass criterion is satisfied with maximum combined ponding/profile residuals of about `3.56e-8 cm` for both runs.

Deterministic reconstruction gives the B1.6 source-tree identity:

```text
members          63
source bytes      1,860,085
manifest SHA-256  aad530d2b683aa25ed8d5ec87656fb3790b8d8f8faf6bff4b03d40a4c60136a0
```

This legacy mass evidence qualifies the B1 correction; future B2 hard mass qualification still uses the separate transaction-aware unrounded accounting contract.

## Current use rule

`reference/swap-4.3.1/b1-manifest.yml` points to `B1.6`. B1.6 is the corrected legacy oracle to be used for future B2 reference comparisons until a later immutable corrected snapshot supersedes it.

Historical B1.2-B1.5 remain audit records only. Candidate dossiers under `patches/` do not affect B1 unless they are present in the ordered current manifest. SWAP-011, for example, remains `PATCH_PAYLOAD_PENDING` and is not part of B1.6.
