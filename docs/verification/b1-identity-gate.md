# B1 corrected-reference identity gate

## Purpose

Before a corrected SWAP 4.3.1 snapshot is used as an exact B1 oracle, its stored artifacts must be cryptographically consistent with the canonical B0 source identity and with each other.

This gate was added after VQ found provenance mismatches in the historical B1.2-B1.5 metadata. Those historical snapshots remain immutable audit records; `B1.5p1` is the provenance-repaired replacement definition.

## Gate implementation

The fail-closed verifier is:

```text
reference/swap-4.3.1/verify_b1_identity.py
```

CI runs it through:

```text
.github/workflows/reference-identity.yml
```

For the current repaired reference the CI invocation is:

```text
python reference/swap-4.3.1/verify_b1_identity.py \
  --expect-snapshot B1.5p1 \
  --json
```

The workflow enables Bash `pipefail`, so a verifier failure cannot be hidden by the `tee` command used to preserve machine-readable evidence.

## What is verified

The gate verifies, without compiling Fortran:

1. the current `b1-manifest.yml` snapshot and snapshot-definition file agree;
2. the B0 source-archive identity and expanded-member-manifest identity agree between the two control files;
3. the stored `file-manifest.sha256` itself has the declared SHA-256;
4. patch order is identical in the current manifest and snapshot definition;
5. every stored `fix.patch` hashes exactly to its declared SHA-256;
6. every declared B0 target preimage equals the canonical target-member SHA in `b0/file-manifest.sha256`;
7. every qualification artifact exists;
8. each admitted patch has a byte-verification helper that pins the canonical B0 target hash; when a helper also pins a corrected-target SHA, that SHA must agree with the snapshot;
9. the complete identity evidence is reduced to a deterministic SHA-256 fingerprint.

Any missing file, malformed digest, patch hash mismatch, non-canonical B0 preimage, helper mismatch or patch-order difference causes the gate to fail.

## Corrected-target boundary

The snapshot records a deterministic corrected-target SHA for every admitted patch. Some per-patch helpers independently pin that corrected-target SHA, while older helpers compute and print it after transformation without storing it as a constant.

Because the byte-exact expanded B0 source tree is not committed to Git, this repository-only CI gate does **not** claim to reapply every patch to raw B0 bytes and independently recompute all corrected-target hashes. That stronger application check requires the canonical B0 source archive or a binary-safe unpacked B0 tree.

The CI evidence reports this limitation explicitly. This does not weaken the provenance check requested by issue #19: the stored patch bytes and each declared B0 preimage are still checked fail-closed against their canonical identities.

## What this gate does not prove

A PASS is an **artifact/preimage identity result**, not a numerical or physical qualification result.

It does not:

- compile SWAP;
- execute a SWAP case;
- prove that a corrected target compiles on a particular Fortran compiler;
- independently reapply every patch to an unpacked byte-exact B0 tree inside CI;
- replace the original per-fix regression evidence;
- establish water-balance correctness for a newly admitted physically active fix;
- qualify SWAP5 B2 against B1.

Where a new correction changes physically active behavior, the normal regression and hard mass-balance gates remain mandatory in addition to this identity gate.

## Use in the B1 admission chain

The intended sequence is:

```text
canonical B0 identity
        -> exact patch provenance
        -> B1 artifact/preimage identity gate PASS
        -> optional raw-B0 patch-application identity gate
        -> per-fix compile/run/regression evidence
        -> hard water-balance gate where physically relevant
        -> immutable B1 snapshot
        -> B2 reference qualification
```

For `SWAP-009`, for example, a successful identity gate for the repaired B1 base does not by itself admit the PDI Kelvin-sign correction. The dedicated PDI hydraulic testbank, representative production-path regression and hard water-balance evidence remain required.
