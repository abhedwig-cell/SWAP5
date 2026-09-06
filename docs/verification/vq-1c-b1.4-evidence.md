# VQ-1c B1.4 provenance evidence

**Workstream:** VQ  
**Slice:** VQ-1c  
**Pinned integration commit:** `ce280e110c637a087d2a1aabd70fca5f1d494e48`  
**Pinned snapshot:** `B1.4`  
**Decision:** FAIL CLOSED

## Gate

Before B1 may be used as a numerical oracle, VQ requires every snapshot-declared patch artifact to exist and match its declared SHA-256. Where the snapshot declares a B0 target preimage, that identity must also match canonical B0.

The machine-readable pin is:

```text
tools/vq/cases/b1-4-reference-pin.json
```

## Patch artifact identities

Exact stored `fix.patch` bytes at the pinned commit give:

| Patch | Declared by B1.4 | Observed | Status |
| --- | --- | --- | --- |
| SWAP-001 | `6dd75db2603f71def58db0a0f5c77bfcd2fba2688add837436fd0d09713e5770` | same | PASS |
| SWAP-005 | `9c3839ac0674d7c5c3eb2de797684c7baf83fdc3a18d64de68c9746de9878e66` | `243720f59a0d9154fa4ba4acf1fce68096999bd0f8eafa452bfb40cef5572553` | FAIL |
| SWAP-006 | `558eb084befac713aec0b923d45182a1efcbed44d71ed00e6faf024b6540718a` | `4530d489701f0356dd06d8cc3752b3cb6322cf864cea0c330ce1448f7dfa5b2f` | FAIL |
| SWAP-007 | `e65b703b73b530915414265c3b647a403f995adc568390ed5da4ecb55be75b96` | `3ac9580bc162f8a4c90b83d59452e7b40bd1e0c82ba92e7a2c1ac58f154af5f0` | FAIL |

The observed hashes were computed from GitHub's exact base64 file content, not normalized text.

## Independent canonical B0 preimage check

The exact B0 distribution used by VQ has SHA-256:

```text
2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360
```

Its embedded `tools/SWAP/source/SWAP.ZIP` has SHA-256:

```text
1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151
```

Direct extraction of the four relevant exact source members gives:

```text
SWAP/macropore.f90              1cb5a2ce30610c05a4da5655bff217d6f52052d57d99efe8af7928f1d2187d0b
SWAP/MOD_cropdevelopment.f90    c2df137291357553541d4d7026b8859242c32565affe173c66a685d565190ccf
SWAP/MOD_meteo.f90              5a095c16ec82fa544f7dd20ba568ba3a2b72906bff7dd3505af16e6722d86822
SWAP/oxygenstress.f90           2db206bf28e883a22a1419d4729e03c1bb6b1ec777f544511ffe95bdbf9e5735
```

The first three agree with their canonical B0 identities. B1.4/SWAP-007 instead declares:

```text
2db206bf28e883a22a1419d4729e03c1bb6b9c6bcf560d2221248f3b12f75
```

which does not match canonical B0.

## Interpretation

This evidence establishes a reference-provenance failure. It does **not** by itself establish that the intended SWAP-005/006/007 correction semantics are physically or numerically wrong.

VQ therefore keeps two questions separate:

1. is the proposed correction qualified technically;
2. is the immutable B1 oracle artifact chain cryptographically anchored to canonical B0.

The second question currently fails for B1.4, which is sufficient to block B1.4 as an exact verification oracle.

## Decision

```text
B1.4 snapshot present:                   PASS
SWAP-001 patch artifact:                 PASS
SWAP-005 patch artifact:                 FAIL
SWAP-006 patch artifact:                 FAIL
SWAP-007 patch artifact:                 FAIL
SWAP-007 canonical B0 preimage identity: FAIL
B1.4 exact oracle identity:              FAIL
B0 -> B1.4 numerical qualification:      BLOCKED
```

GitHub issue #19 owns the reference-line resolution. VQ does not mutate published immutable B1.3/B1.4 snapshots in place.

## Next acceptance condition

A new or otherwise provenance-correct immutable B1 snapshot must pass `tools/vq/b1_snapshot_identity.py` and its declared B0 preimages before VQ admits any B0 -> B1 numerical comparison.
