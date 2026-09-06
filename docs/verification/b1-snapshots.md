# B1 corrected-reference snapshots

B1 is an ordered sequence of corrected SWAP 4.3.1 reference definitions. Each snapshot starts from the same byte-identified B0 source and adds only admitted, qualified bug fixes. Published snapshots are immutable.

## Snapshot history

| Snapshot | Admitted patches | Exact-oracle status | Meaning |
| --- | --- | --- | --- |
| `B1.0-bootstrap` | none | historical | exact B0, no corrections |
| `B1.1` | `SWAP-001` | historical | first corrected reference |
| `B1.2` | + `SWAP-005` | **do not use as exact oracle** | provenance mismatch found by VQ-1c |
| `B1.3` | + `SWAP-006` | **do not use as exact oracle** | provenance mismatch |
| `B1.4` | + `SWAP-007` | **do not use as exact oracle** | provenance mismatch |
| `B1.5` | + `SWAP-008` | **do not use as exact oracle** | provenance mismatch |
| `B1.5p1` | same five intended corrections | qualified predecessor | provenance repaired and targeted gates PASS |
| `B1.6` | + `SWAP-009` | qualified predecessor | PDI Kelvin-sign correction |
| `B1.7` | + `SWAP-010` | qualified predecessor | model-7 capacity-derivative correction |
| `B1.8` | + `SWAP-013` | qualified predecessor | PDI `HA/H0` input-domain guard |
| `B1.9` | + `SWAP-012` | **current qualified corrected reference** | `prhead` inverse corrected for models 3 and 5-12 |

The exact definitions live under `reference/swap-4.3.1/snapshots/`.

## Admitted corrections through B1.9

`SWAP-001` fixes the non-conformable macropore assignment. `SWAP-005` removes reliance on short-circuit evaluation in crop-calendar bounds checking. `SWAP-006` removes the implicit zero-initialization sentinel in the meteo crop loop. `SWAP-007` guards the oxygen-stress Newton update against an unrepresentable quotient while preserving the existing restart route. `SWAP-008` corrects fallback band-solver dummy-argument contracts without changing arithmetic. `SWAP-009` fixes the PDI Kelvin-sign vapor-conductivity caller error. `SWAP-010` makes model-7 capacity consistent with the implemented retention curve. `SWAP-013` rejects singular PDI `HA/H0` combinations before constitutive evaluation.

`SWAP-012`, first admitted in B1.9, corrects `prhead`: hydraulic models 3 and 5-12 no longer fall through to the default unimodal MvG analytical inverse when their actual retention relation is different. The repair uses the selected retention relation in a robust bracketed/bisection inverse. Model 4 retains its analytical default-MvG inverse. The historical SWAP-011 `dhconduc` content is explicitly excluded.

## SWAP-012 qualification

The broader D2 qualification tested 22,240 valid affected-model round trips. The legacy inverse had 17,176 errors above `0.01` decade; the corrected inverse had 0 failures and maximum corrected error `2.09e-8` decade.

A separate isolated actual-source GNU Fortran gate compiled canonical B0 `MOD_MvG_functions.f90` and the exact SWAP-012-only corrected target with matched support modules. It exercised 60 pressure heads for each model 3-12, including model 4 as an unaffected control:

```text
B0 failures          513 / 600
corrected failures     0 / 600
B0 max error          7.4915 decades
corrected max error   1.17e-10 decade
criterion             1e-6 decade
```

Exact identity:

```text
canonical B0 / ordered B1.8 target SHA-256
a27252d216da65ce20ed3a173ade5404a0f31241ac87349edadb3b3ff9d63390

SWAP-012 fix.patch SHA-256
263e515b7c80059c13e71fcbc3dc1f187b6d0673e07c0c265bbc140fea0df131

corrected target SHA-256
4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1
```

Deterministic B1.9 source identity:

```text
members          63
source bytes      1,863,300
manifest SHA-256  5e28510813e5748bae52ffd5c08027bb55b63858aa994ea90635b632826de657
```

SWAP-012 changes no retention or conductivity formula, no Richards residual/Jacobian, no solver policy and no mass-balance tolerance. A future faster model-specific inverse is an optimization and must qualify against the B1.9 inverse contract.

## Current use rule

`reference/swap-4.3.1/b1-manifest.yml` points to `B1.9`. Historical B1.2-B1.5 remain audit records only; B1.5p1 through B1.8 remain immutable qualified predecessors. SWAP-011 remains `PATCH_PAYLOAD_PENDING` and is not part of B1.9.
