# VQ-1c B1.5p1 independent identity evidence

**Workstream:** VQ  
**Slice:** VQ-1c  
**Reference-line commit re-read:** `0fbcb17ddf93762fc256de6c38f511eadfd01eb4`  
**Pinned snapshot:** `B1.5p1`  
**Decision:** PASS identity gate

## Why this gate exists

Historical B1.2-B1.5 snapshots remain immutable audit records but failed exact provenance checks for several stored patch hashes and, for SWAP-007, the canonical B0 preimage identity. The reference line responded by publishing `B1.5p1` as a new provenance-repair snapshot rather than rewriting history.

VQ independently repins the replacement before allowing numerical B0 -> B1 comparison.

## Exact snapshot and canonical B0 manifest

VQ pins:

```text
snapshot path:
reference/swap-4.3.1/snapshots/B1.5p1.yml

snapshot Git blob SHA-1:
8980a975f4a8183bd216f03d868657568b5317d4

canonical B0 member manifest:
reference/swap-4.3.1/b0/file-manifest.sha256

canonical manifest Git blob SHA-1:
be8862be45415e49fc366f98d9de76c8b14b1fae

B0 source archive SHA-256:
1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151
```

The machine-readable VQ pin is `tools/vq/cases/b1-5p1-reference-pin.json`.

## Patch artifact identities

VQ re-read the exact stored patch bytes and independently computed SHA-256:

| Patch | B1.5p1 declared SHA-256 | VQ observed | Gate |
| --- | --- | --- | --- |
| SWAP-001 | `6dd75db2603f71def58db0a0f5c77bfcd2fba2688add837436fd0d09713e5770` | same | PASS |
| SWAP-005 | `243720f59a0d9154fa4ba4acf1fce68096999bd0f8eafa452bfb40cef5572553` | same | PASS |
| SWAP-006 | `4530d489701f0356dd06d8cc3752b3cb6322cf864cea0c330ce1448f7dfa5b2f` | same | PASS |
| SWAP-007 | `3ac9580bc162f8a4c90b83d59452e7b40bd1e0c82ba92e7a2c1ac58f154af5f0` | same | PASS |
| SWAP-008 | `8f97ff20e63a7765bfe8e225e2682029bafadc0eeb80ad0e4ce1564fb8c94f4c` | same | PASS |

## Canonical B0 preimages

The B1.5p1 declarations also match the canonical 63-member B0 manifest:

| Patch | Target | Canonical B0 SHA-256 | Gate |
| --- | --- | --- | --- |
| SWAP-001 | `SWAP/macropore.f90` | `1cb5a2ce30610c05a4da5655bff217d6f52052d57d99efe8af7928f1d2187d0b` | PASS |
| SWAP-005 | `SWAP/MOD_cropdevelopment.f90` | `c2df137291357553541d4d7026b8859242c32565affe173c66a685d565190ccf` | PASS |
| SWAP-006 | `SWAP/MOD_meteo.f90` | `5a095c16ec82fa544f7dd20ba568ba3a2b72906bff7dd3505af16e6722d86822` | PASS |
| SWAP-007 | `SWAP/oxygenstress.f90` | `2db206bf28e883a22a1419d4729e03c1bb6b1ec777f544511ffe95bdbf9e5735` | PASS |
| SWAP-008 | `SWAP/tridag.f90` | `6aa6bb863ec296f47afda35a9871b16105087d0eed485e37f13f5f5cdad96651` | PASS |

The SWAP-007 entry now uses the canonical B0 identity that VQ independently obtained from the exact B0 source archive.

## Scope of PASS

This PASS means:

- the replacement snapshot itself is pinned;
- the stored patch artifacts are exactly the bytes declared by B1.5p1;
- every declared patch target starts from the canonical B0 member identity;
- the provenance repair did not silently mutate B1.2-B1.5;
- the intended patch set remains the same five corrections.

It does **not** yet mean that B1.5p1 is numerically qualified against B0. Patch application, corrected-target verification and executable regression are the next gate.

The patch files are LF-formatted audit artifacts while canonical B0 source members may retain historical line endings. A raw generic `patch` invocation is therefore not itself the oracle application contract. VQ will use or define a deterministic, byte-aware application path before numerical comparison.

## Decision

```text
B1.5p1 snapshot identity:             PASS
canonical B0 member manifest identity: PASS
all stored patch artifact hashes:      PASS
all declared canonical B0 preimages:   PASS
B1 exact identity gate:                PASS
B0 -> B1 numerical qualification:      NEXT GATE
```

## Issue #19

Issue #19's original blocker is resolved by a new immutable provenance-repair snapshot rather than modification of the failed historical snapshots. VQ may close the provenance blocker while retaining B1.2-B1.5 as historical failed-oracle evidence.

## Next safe step

Build a deterministic B1.5p1 application adapter starting from exact B0 bytes, verify each corrected target against the B1.5p1 corrected-target SHA-256, then execute the first B0 -> B1 comparison using the expected-difference ledger.
