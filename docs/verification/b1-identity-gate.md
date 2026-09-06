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

## What is verified

The gate verifies, without compiling Fortran:

1. the current `b1-manifest.yml` snapshot and snapshot-definition file agree;
2. the B0 source-archive identity and expanded-member-manifest identity agree between the two control files;
3. the stored `file-manifest.sha256` itself has the declared SHA-256;
4. patch order is identical in the current manifest and snapshot definition;
5. every stored `fix.patch` hashes exactly to its declared SHA-256;
6. every declared B0 target preimage equals the canonical target-member SHA in `b0/file-manifest.sha256`;
7. every qualification artifact exists;
8. each admitted patch has a byte-verification helper that pins the canonical B0 target hash and the documented corrected-target hash;
9. the complete identity evidence is reduced to a deterministic SHA-256 fingerprint.

Any missing file, malformed digest, patch hash mismatch, non-canonical B0 preimage, helper mismatch or patch-order difference causes the gate to fail.

## What this gate does not prove

A PASS is an **identity/provenance result**, not a numerical or physical qualification result.

It does not:

- compile SWAP;
- execute a SWAP case;
- prove that a corrected target compiles on a particular Fortran compiler;
- replace the original per-fix regression evidence;
- establish water-balance correctness for a newly admitted physically active fix;
- qualify SWAP5 B2 against B1.

Where a new correction changes physically active behavior, the normal regression and hard mass-balance gates remain mandatory in addition to this identity gate.

## Use in the B1 admission chain

The intended sequence is:

```text
canonical B0 identity
        -> exact patch provenance
        -> B1 identity gate PASS
        -> per-fix compile/run/regression evidence
        -> hard water-balance gate where physically relevant
        -> immutable B1 snapshot
        -> B2 reference qualification
```

For `SWAP-009`, for example, a successful identity gate for the repaired B1 base does not by itself admit the PDI Kelvin-sign correction. The dedicated PDI hydraulic testbank, representative production-path regression and hard water-balance evidence remain required.
