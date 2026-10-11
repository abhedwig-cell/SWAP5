# B0 source encoding notes

B0 is a byte-preserving reference, not merely a collection of visually equivalent text files.

Inspection of the canonical source archive shows that 62 of the 63 Fortran members are valid UTF-8/ASCII byte streams. `SWAP/MOD_RIA.f90` is not valid UTF-8. Its non-ASCII bytes are:

| Byte | Count | Windows-1252 interpretation |
| --- | ---: | --- |
| `0x96` | 5 | en dash |
| `0xB4` | 1 | acute accent |
| `0xFC` | 1 | `ü` |

The pattern is consistent with Windows-1252 text, but B0 verification does not depend on assigning an encoding. The raw bytes and SHA-256 are normative.

## Consequence for Git import

A text-only upload path that transparently decodes and re-encodes source files must **not** be used to claim an exact B0 import. In particular, converting `MOD_RIA.f90` to UTF-8 would change its byte hash even if the Fortran semantics and rendered comment text remained unchanged.

The exact member hash is recorded in `file-manifest.sha256`, and `verify_source_archive.py` checks raw bytes. A future unpacked B0 source tree may be committed only through a binary-safe Git path or after proving every committed file reproduces the manifest byte-for-byte.

This restriction applies to B0 only as historical reference identity. Normal SWAP5 source files may follow the repository's chosen text-encoding policy.
