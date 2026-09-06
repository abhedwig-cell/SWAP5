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

## Release metadata

- model: SWAP 4.3.1
- package release date: 2026-06-30
- release classification: development release
- supplied Windows compiler metadata: Intel Fortran Classic 2021.9.0, build 20230302_000000

## Immutability rule

No bug fix, refactor, formatting change or model development is permitted to alter B0. Any confirmed correction is represented as a B1 patch outside this directory.

If the B0 source payload is mirrored, extracted, encoded or moved within Git later, the decoded/reconstructed source archive must reproduce SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.
