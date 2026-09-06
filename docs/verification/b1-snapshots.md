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
| `B1.6` | B1.5p1 + `SWAP-009` | qualified predecessor oracle | adds the qualified PDI Kelvin-sign vapor-conductivity correction |
| `B1.7` | B1.6 + `SWAP-010` | **current qualified corrected reference** | adds the qualified model-7 capacity-derivative consistency correction |

The exact definitions live under `reference/swap-4.3.1/snapshots/`.

## Admitted corrections through B1.7

`SWAP-001` fixes the non-conformable macropore assignment. `SWAP-005` removes reliance on short-circuit evaluation in crop-calendar bounds checking. `SWAP-006` removes the implicit zero-initialization sentinel in the meteo crop loop. `SWAP-007` guards the oxygen-stress Newton update against an unrepresentable quotient while preserving the existing restart route. `SWAP-008` corrects the fallback band-solver dummy-argument contracts from `INTENT(OUT)` to `INTENT(INOUT` without changing solver arithmetic.

`SWAP-009`, first admitted in `B1.6`, corrects four PDI conductivity callers that supplied `abs(h)` to a Kelvin vapor-conductivity helper whose implemented relation expects signed negative unsaturated pressure head. The correction passes signed `h`; the Kelvin helper itself is not changed.

`SWAP-010`, first admitted in `B1.7`, corrects the model-7 `C_MvG_2_s` capacity formula so that it is the derivative of the implemented scaled-bimodal water-retention function. It is an algebraic implementation correction, not a new hydraulic model.

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

## B1.6: SWAP-009 admission

SWAP-009 passed exact patch/preimage/corrected-target identity, strict compiled PDI function verification, a representative full PDI production-path regression and a hard unrounded legacy mass gate. Deterministic reconstruction gives:

```text
members          63
source bytes      1,860,085
manifest SHA-256  aad530d2b683aa25ed8d5ec87656fb3790b8d8f8faf6bff4b03d40a4c60136a0
```

B1.6 remains an immutable qualified predecessor.

## B1.7: SWAP-010 admission

SWAP-010 shares `WC_K_models_04_11.f90` with SWAP-009. B1.7 therefore pins both canonical B0 provenance and the exact ordered B1.6 preimage:

```text
canonical B0 target SHA-256
1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd

ordered B1.6 preimage SHA-256
f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7

corrected B1.7 target SHA-256
7ca607b2bbf97e166a32ab8a529fc7f32af9949afb1e6eb518ddbf84e6f0169e
```

The fresh source-bound capacity gate evaluates 1000 model-7 points. B1.6 exceeds the `1e-3` relative-error threshold at 784 points with a maximum relative error of about `1.60e-1`; the corrected source has 0 failures and maximum relative error about `3.33e-8`.

A deterministic two-day full SWAP model-7 case completes normally for both predecessor and candidate. The nonlinear routes differ strongly: B1.6 uses 9997 four-iteration steps plus 3 five-iteration steps, while the corrected case uses 57 two-iteration steps. This is qualification evidence only, not a performance benchmark.

With `CRITDEVMASBAL = 1e-6 cm` fixed before comparison, the maximum unrounded diagnostic residual is about `1.58e-6 cm` for B1.6 and `1.00e-8 cm` for the corrected candidate. B1.6 creates `result.dwb`; the candidate does not. No tolerance or mass criterion is relaxed.

Deterministic reconstruction gives the B1.7 source-tree identity:

```text
members          63
source bytes      1,860,091
manifest SHA-256  62939097cfcdb59f8fe8c9161356fc703d7c54d6dd61ab3c31b19c2cfea6a5ba
```

## Current use rule

`reference/swap-4.3.1/b1-manifest.yml` points to `B1.7`. B1.7 is the corrected legacy oracle to be used for future B2 reference comparisons until a later immutable corrected snapshot supersedes it.

Historical B1.2-B1.5 remain audit records only. Qualified B1.5p1 and B1.6 remain immutable predecessors. Candidate dossiers under `patches/` do not affect B1 unless they are present in the ordered current manifest. SWAP-011 remains `PATCH_PAYLOAD_PENDING` and is not part of B1.7.
