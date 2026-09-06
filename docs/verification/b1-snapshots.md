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
| `B1.9` | + `SWAP-012` | qualified predecessor | `prhead` inverse corrected for models 3 and 5-12 |
| `B1.10` | + `SWAP-002` | **current qualified corrected reference** | tillage start-event pointer/history initialization corrected |

The exact definitions live under `reference/swap-4.3.1/snapshots/`.

## Admitted corrections through B1.10

`SWAP-001` fixes the non-conformable macropore assignment. `SWAP-005` removes reliance on short-circuit evaluation in crop-calendar bounds checking. `SWAP-006` removes the implicit zero-initialization sentinel in the meteo crop loop. `SWAP-007` guards the oxygen-stress Newton update against an unrepresentable quotient while preserving the existing restart route. `SWAP-008` corrects fallback band-solver dummy-argument contracts without changing arithmetic. `SWAP-009` fixes the PDI Kelvin-sign vapor-conductivity caller error. `SWAP-010` makes model-7 capacity consistent with the implemented retention curve. `SWAP-013` rejects singular PDI `HA/H0` combinations before constitutive evaluation. `SWAP-012` corrects the inverse retention dispatch for models 3 and 5-12 while explicitly excluding SWAP-011.

`SWAP-002`, first admitted in B1.10, fixes `set_iTill`. The B0 interval condition uses the same event date as both lower and upper bound and therefore can never select a later event. B1.10 defines `iTill` as the first event on or after the simulation start; after the final event it is `Ntill+1`. If the start follows a historical event, the most recent previous tillage/consolidation parameters are loaded.

## SWAP-002 qualification

The audit testbank established six start-position semantics. A fresh strict GNU Fortran source-bound gate repeats these cases and verifies the loaded previous-event index:

```text
case                 B0       B1.10
before first         PASS     PASS
exact first          PASS     PASS
between event 1/2    FAIL     PASS
exact event 2        FAIL     PASS
after final          FAIL     PASS
unsorted dates       PASS     PASS

total                3/6      6/6
```

Exact identity:

```text
canonical B0 / ordered B1.9 tillage.f90 SHA-256
731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486

SWAP-002 fix.patch SHA-256
e6f501f510f0de3599cfb2ef208744862e7ef9173c9cf1bf434f2e3ea450613b

corrected tillage.f90 SHA-256
eaf1976238f7c659c1acb02f54685a7aafdf03d50d0978bbcc788b6ada441ca3
```

Deterministic B1.10 source identity:

```text
members          63
source bytes      1,863,575
manifest SHA-256  2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1
```

SWAP-002 changes only start-state/event-index semantics. SWAP-003 (`PCLAY=0`) and SWAP-004 (tillage type indexing) remain outside B1.10. No solver policy or mass-balance tolerance changes. B0 contains no standard full tillage scenario, so this admission does not claim exhaustive qualification of all tillage process interactions.

## Current use rule

`reference/swap-4.3.1/b1-manifest.yml` points to `B1.10`. Historical B1.2-B1.5 remain audit records only; B1.5p1 through B1.9 remain immutable qualified predecessors. SWAP-011 remains `PATCH_PAYLOAD_PENDING` and is not part of B1.10.
