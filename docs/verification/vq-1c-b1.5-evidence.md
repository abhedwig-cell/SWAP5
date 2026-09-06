# VQ-1c B1.5 provenance evidence

**Workstream:** VQ  
**Slice:** VQ-1c  
**Latest main re-read:** `3fe22ac2ac5c16fac015c8bee3d46cec6e7ba443`  
**Pinned snapshot:** `B1.5`  
**Decision:** FAIL CLOSED

## Snapshot identity

B1.5 adds SWAP-008 on top of B1.4. VQ checks every stored patch artifact against the SHA-256 declared by `reference/swap-4.3.1/snapshots/B1.5.yml` before any B0 -> B1 numerical comparison.

Machine-readable pin:

```text
tools/vq/cases/b1-5-reference-pin.json
```

| Patch | Declared SHA-256 | Observed stored patch | Status |
| --- | --- | --- | --- |
| SWAP-001 | `6dd75db2603f71def58db0a0f5c77bfcd2fba2688add837436fd0d09713e5770` | same | PASS |
| SWAP-005 | `9c3839ac0674d7c5c3eb2de797684c7baf83fdc3a18d64de68c9746de9878e66` | `243720f59a0d9154fa4ba4acf1fce68096999bd0f8eafa452bfb40cef5572553` | FAIL |
| SWAP-006 | `558eb084befac713aec0b923d45182a1efcbed44d71ed00e6faf024b6540718a` | `4530d489701f0356dd06d8cc3752b3cb6322cf864cea0c330ce1448f7dfa5b2f` | FAIL |
| SWAP-007 | `e65b703b73b530915414265c3b647a403f995adc568390ed5da4ecb55be75b96` | `3ac9580bc162f8a4c90b83d59452e7b40bd1e0c82ba92e7a2c1ac58f154af5f0` | FAIL |
| SWAP-008 | `8f97ff20e63a7765bfe8e225e2682029bafadc0eeb80ad0e4ce1564fb8c94f4c` | same | PASS |

## B0 preimages

SWAP-007 still declares B0 `SWAP/oxygenstress.f90` SHA-256:

```text
2db206bf28e883a22a1419d4729e03c1bb6b9c6bcf560d2221248f3b12f75
```

Independent extraction from the exact B0 source archive gives:

```text
2db206bf28e883a22a1419d4729e03c1bb6b1ec777f544511ffe95bdbf9e5735
```

Therefore the inherited SWAP-007 B0 preimage gate remains failed.

The new SWAP-008 provenance is internally consistent. Exact B0 `SWAP/tridag.f90` gives:

```text
6aa6bb863ec296f47afda35a9871b16105087d0eed485e37f13f5f5cdad96651
```

which matches the B1.5 declaration, and the stored SWAP-008 patch bytes match their declared SHA-256.

## Interpretation

The newly admitted SWAP-008 artifact is not the cause of the B1.5 qualification failure. B1.5 inherits unresolved provenance failures from SWAP-005, SWAP-006 and SWAP-007.

This remains a provenance/oracle-integrity finding. It does not by itself invalidate the technical correction semantics of those patches.

## Decision

```text
B1.5 snapshot present:                   PASS
SWAP-001 artifact:                       PASS
SWAP-005 artifact:                       FAIL
SWAP-006 artifact:                       FAIL
SWAP-007 artifact:                       FAIL
SWAP-007 canonical B0 preimage identity: FAIL
SWAP-008 artifact:                       PASS
SWAP-008 canonical B0 preimage identity: PASS
B1.5 exact oracle identity:              FAIL
B0 -> B1.5 numerical qualification:      BLOCKED
```

GitHub issue #19 remains the reference-line blocker. VQ does not mutate published B1 snapshots to force agreement.

## Next acceptance condition

A provenance-correct immutable B1 snapshot must pass `tools/vq/b1_snapshot_identity.py` and all declared B0 preimages before VQ executes or admits B0 -> B1 numerical comparison evidence.
