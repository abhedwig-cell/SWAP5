# B0 source identity

This file identifies the immutable SWAP 4.3.1 audit baseline used by the SWAP5 project.

## Controlling hashes

| Artifact | SHA-256 |
| --- | --- |
| Supplied distribution `SWAP_4.3.1.zip` | `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360` |
| Nested Fortran archive `tools/SWAP/source/SWAP.ZIP` | `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151` |
| Windows executable | `d13f5e0321db1780d211520287dc59db2e7aa763649998a4b29a187195ca89a5` |
| Linux executable | `e3b45c1fe66a614c1caead4b2fc0684a09165672a32d8d3bf4eac00498767862` |

The nested Fortran archive contains 63 Fortran source files under `SWAP/` and has an uncompressed source size of 1,859,823 bytes.

## Expanded-source identity

`file-manifest.sha256` records the raw-byte SHA-256 and byte size of every one of the 63 source members. Its purpose is to make an unpacked B0 tree independently checkable instead of relying only on the ZIP archive hash.

`verify_source_archive.py` checks:

1. the complete `SWAP.ZIP` SHA-256;
2. the exact set of source members;
3. the byte size of every source member;
4. the SHA-256 of every source member.

The verifier has been exercised against the canonical B0 archive and all 63 members matched.

## Release metadata

- model: SWAP 4.3.1
- package release date: 2026-06-30
- release classification: development release
- supplied Windows compiler metadata: Intel Fortran Classic 2021.9.0, build 20230302_000000

## Byte-preserving import rule

B0 is defined by bytes, not by visually equivalent source text. `SWAP/MOD_RIA.f90` contains non-UTF-8 bytes. See `ENCODING_NOTES.md`.

An unpacked Git source mirror is therefore accepted as B0 only after its raw files reproduce `file-manifest.sha256`. A text tool that silently converts encodings or line endings is not an acceptable import path for claiming exact B0 identity.

Until such a binary-safe unpacked import is completed, the source archive SHA-256 plus the per-member manifest are the controlling B0 source identity.

## Immutability rule

No bug fix, refactor, formatting change, newline conversion, encoding conversion or model development is permitted to alter B0. Any confirmed correction is represented as a B1 patch outside this directory.
