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
| `B1.7` | B1.6 + `SWAP-010` | qualified predecessor oracle | adds the qualified model-7 capacity-derivative consistency correction |
| `B1.8` | B1.7 + `SWAP-013` | **current qualified corrected reference** | adds the qualified PDI `HA/H0` relational input-domain guard |

The exact definitions live under `reference/swap-4.3.1/snapshots/`.

## Admitted corrections through B1.8

`SWAP-001` fixes the non-conformable macropore assignment. `SWAP-005` removes reliance on short-circuit evaluation in crop-calendar bounds checking. `SWAP-006` removes the implicit zero-initialization sentinel in the meteo crop loop. `SWAP-007` guards the oxygen-stress Newton update against an unrepresentable quotient while preserving the existing restart route. `SWAP-008` corrects the fallback band-solver dummy-argument contracts from `INTENT(OUT)` to `INTENT(INOUT)` without changing solver arithmetic.

`SWAP-009`, first admitted in `B1.6`, corrects four PDI conductivity callers that supplied `abs(h)` to a Kelvin vapor-conductivity helper whose implemented relation expects signed negative unsaturated pressure head. The correction passes signed `h`; the Kelvin helper itself is not changed.

`SWAP-010`, first admitted in `B1.7`, corrects the model-7 `C_MvG_2_s` capacity formula so that it is the derivative of the implemented scaled-bimodal water-retention function. It is an algebraic implementation correction, not a new hydraulic model.

`SWAP-013`, first admitted in `B1.8`, adds an input-domain guard for PDI hydraulic models 8-11 after the existing `H0`/`HA` magnitude conversion. It requires `0 < HA < H0`, preventing singular combinations such as `HA=0` or `HA=H0` from reaching logarithmic constitutive expressions. Accepted PDI equations are unchanged.

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

## B1.6 and B1.7

SWAP-009 passed exact patch/preimage/corrected-target identity, strict compiled PDI function verification, a representative full PDI production-path regression and a hard unrounded legacy mass gate. B1.6 remains an immutable qualified predecessor.

SWAP-010 then passed a source-bound capacity-derivative gate and a representative full model-7 run. B1.7 explicitly pins the ordered B1.6 preimage because SWAP-009 and SWAP-010 share `WC_K_models_04_11.f90`. With the predeclared `CRITDEVMASBAL = 1e-6 cm`, the sensitive corrected model-7 run closes at about `1.00e-8 cm`; no tolerance is relaxed. B1.7 remains an immutable qualified predecessor.

## B1.8: SWAP-013 admission

SWAP-013 targets `SWAP/readswap.f90`, which is unchanged by B1.1-B1.7. The exact ordered B1.7 preimage therefore equals canonical B0:

```text
canonical B0 / ordered B1.7 preimage SHA-256
3ab42ae4ad9a76d96b01d90b173cf821a9add8514620a965bf31eaf874405cf2

SWAP-013 fix.patch SHA-256
066c1c1aba8f32cb3a9aab3d17f1900b0ba8a28f43173d80461c91fb1a8f25f3

corrected B1.8 readswap.f90 SHA-256
e2ddee83afde65d5c10af561c8271c2cd6f23065d431160bf1467d5ebd18768c
```

The source-bound strict GNU Fortran guard gate checks placement after magnitude conversion and before further PDI parameter intake, then exercises nine cases: four valid PDI combinations accepted, three singular/invalid PDI combinations rejected, and two non-PDI controls unaffected. Result: `SWAP-013_GUARD_HARNESS PASS 9/9`.

Because the correction acts during validation before time integration, the expected difference is input rejection only. No accepted-input retention, capacity, conductivity, solver or water-balance equation changes.

Deterministic reconstruction gives the B1.8 source-tree identity:

```text
members          63
source bytes      1,860,493
manifest SHA-256  e32395a6dc1c4ad0caa551739c411669f0b51117dcf68ba719cad75a82fbdcae
```

## Current use rule

`reference/swap-4.3.1/b1-manifest.yml` points to `B1.8`. B1.8 is the corrected legacy oracle to be used for future B2 reference comparisons until a later immutable corrected snapshot supersedes it.

Historical B1.2-B1.5 remain audit records only. Qualified B1.5p1, B1.6 and B1.7 remain immutable predecessors. Candidate dossiers under `patches/` do not affect B1 unless they are present in the ordered current manifest. SWAP-011 remains `PATCH_PAYLOAD_PENDING` and is not part of B1.8.
