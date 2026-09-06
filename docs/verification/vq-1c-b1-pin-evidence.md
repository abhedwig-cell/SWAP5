# VQ-1c B1.3 pin evidence

## Integration record

```text
WORKSTREAM: VQ
SLICE: VQ-1c
CURRENT MAIN PINNED: 5c549e950df98d0cf0c0ef22ac1b682ec2d3bef1
TARGET SNAPSHOT: B1.3
PRODUCTION CODE CHANGED: no
INTERFACES CHANGED: no
PRIMARY INVARIANTS: 13, 25, 30
```

## Purpose

VQ-1c must establish the exact corrected-reference oracle before any B0 -> B1 numerical comparison is admitted. The gate verifies both the B0 provenance and every patch-artifact identity pinned by the immutable B1 snapshot.

A semantic description of a patch is insufficient. If `B1.3.yml` declares a `patch_sha256`, the bytes at its declared `patch_path` must have that SHA-256.

## Snapshot declaration

At current-main commit:

```text
5c549e950df98d0cf0c0ef22ac1b682ec2d3bef1
```

`reference/swap-4.3.1/b1-manifest.yml` declares:

```text
snapshot: B1.3
status: CORRECTED_REFERENCE
patches: SWAP-001, SWAP-005, SWAP-006
published_b1_snapshots: immutable
```

The snapshot definition is:

```text
reference/swap-4.3.1/snapshots/B1.3.yml
Git blob SHA-1: 7e0a5ea03c7ebfda97170d79200294c7f46fda52
```

The B0 source archive identity in the snapshot matches the accepted B0 source identity.

## B0 target preimages

The exact target files extracted from the accepted B0 source archive were hashed before any correction was applied:

| Patch | Target | Expected B0 SHA-256 | Observed | Status |
| --- | --- | --- | --- | --- |
| SWAP-001 | `SWAP/macropore.f90` | `1cb5a2ce30610c05a4da5655bff217d6f52052d57d99efe8af7928f1d2187d0b` | same | PASS |
| SWAP-005 | `SWAP/MOD_cropdevelopment.f90` | `c2df137291357553541d4d7026b8859242c32565affe173c66a685d565190ccf` | same | PASS |
| SWAP-006 | `SWAP/MOD_meteo.f90` | `5a095c16ec82fa544f7dd20ba568ba3a2b72906bff7dd3505af16e6722d86822` | same | PASS |

The failure described below is therefore not caused by an incorrect B0 preimage.

## Patch-artifact identity gate

The exact current GitHub `fix.patch` bytes were retrieved and SHA-256 hashed. SWAP-005 was also checked at the commit that first added its patch (`bc50c12484dc215506a6c2b3fc7cadef978b6241`), and SWAP-006 at its patch-add commit (`a48bc70b0fc2ef243b01fa089f4d8edcc69ce662`). The observed payloads are unchanged from those admission-stage commits.

| Patch | B1.3 expected SHA-256 | Observed `fix.patch` SHA-256 | Status |
| --- | --- | --- | --- |
| SWAP-001 | `6dd75db2603f71def58db0a0f5c77bfcd2fba2688add837436fd0d09713e5770` | `6dd75db2603f71def58db0a0f5c77bfcd2fba2688add837436fd0d09713e5770` | PASS |
| SWAP-005 | `9c3839ac0674d7c5c3eb2de797684c7baf83fdc3a18d64de68c9746de9878e66` | `243720f59a0d9154fa4ba4acf1fce68096999bd0f8eafa452bfb40cef5572553` | **FAIL** |
| SWAP-006 | `558eb084befac713aec0b923d45182a1efcbed44d71ed00e6faf024b6540718a` | `4530d489701f0356dd06d8cc3752b3cb6322cf864cea0c330ce1448f7dfa5b2f` | **FAIL** |

Common newline variants were checked locally for SWAP-005 and SWAP-006 and did not reproduce the declared hashes. The mismatch therefore cannot currently be dismissed as a simple LF/CRLF representation difference.

## Correction-logic cross-check

This provenance failure does **not** establish that the three admitted source corrections are wrong.

The exact B0 preimages were corrected using the byte-safe replacement logic published in the issue helpers. Results:

| Patch | Corrected target SHA-256 | Published expected corrected target | Status |
| --- | --- | --- | --- |
| SWAP-001 | `f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f` | same | PASS |
| SWAP-005 | `aef69feef8561c1b9e52cff5a217a6155f949a039769e5d793df3038f86e4210` | helper produces deterministic output but current qualification does not pin this final hash | DIAGNOSTIC PASS |
| SWAP-006 | `99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f` | same | PASS |

So the current evidence distinguishes two questions:

```text
correction semantics / byte-safe source transformation: supported
published patch-artifact identity for B1.3:             inconsistent
```

VQ does not conflate them.

## Qualification decision

The B1.3 pin fails closed:

```text
B0 identity                         PASS
B0 target preimages                 PASS
B1.3 snapshot declaration           PRESENT
SWAP-001 patch artifact             PASS
SWAP-005 patch artifact             FAIL
SWAP-006 patch artifact             FAIL
B1.3 exact oracle pin               FAIL
B0 -> B1.3 numerical comparison     BLOCKED AS QUALIFICATION EVIDENCE
```

A diagnostic build derived through the published helper logic may be useful for investigation, but VQ must not label such output as an exact B1.3 oracle while the immutable snapshot's declared patch hashes disagree with the stored patch files.

## Why B1.3 is not edited in place

The accepted B1 policy states that published B1 snapshots are immutable. VQ therefore does not repair `B1.3.yml` or its manifest silently.

The B1/reference owner must determine the authoritative cause and choose an explicit provenance-preserving resolution. Examples include recovering the exact patch artifacts whose hashes are already pinned, or creating a new corrected-reference snapshot whose artifact identities match the stored bytes and whose relationship to B1.3 is documented.

VQ does not select that resolution on behalf of the reference-line owner.

## Executable gate

`tools/vq/b1_snapshot_identity.py` verifies a pinned B1 patch set and returns success only when every declared patch file exists and its SHA-256 matches.

`tools/vq/test_b1_snapshot_identity.py` covers:

- exact identity pass;
- hash mismatch fails closed;
- missing patch fails closed.

The machine-readable B1.3 evidence is `tools/vq/cases/b1-3-reference-pin.json`.

## Integration consequence

VQ-1c has discovered a reference-provenance blocker before numerical comparison. This is a successful verification outcome, not a reason to bypass the gate.

Until the B1 reference lineage resolves the patch-artifact mismatch:

- do not use B1.3 as an exact executable production oracle;
- do not admit new B0 -> B1.3 numerical equivalence claims;
- do not change SWAP5 production physics to match a diagnostic reconstruction;
- keep already admitted B1 correction semantics separate from the failed artifact-identity pin.

## Next safe step

Hand this finding to the B1/reference integration owner. Once an immutable, internally self-consistent corrected-reference snapshot is available, rerun the identity gate first. Only after it passes should VQ execute the focused B0 -> B1 edge comparisons and populate expected-difference envelopes.
