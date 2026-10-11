# B0 unpacked-source import gate

Status: **PENDING_BINARY_SAFE_IMPORT**

The canonical B0 source archive has been identified and verified. The repository now contains:

- the canonical source archive SHA-256;
- an exact 63-member raw-byte manifest;
- an archive/member verification program;
- source-encoding notes;
- a B1 bootstrap manifest pinned to the B0 member-manifest digest.

The remaining bootstrap action is to place the 63 source files in an unpacked Git tree without changing a single byte.

## Acceptance conditions

An unpacked import is accepted only if:

1. all 63 expected members are present and no extra source member is introduced;
2. each file byte size matches `file-manifest.sha256`;
3. each file SHA-256 matches `file-manifest.sha256`;
4. no newline normalization has occurred;
5. no character-encoding normalization has occurred;
6. the B0 member-manifest digest remains `d923ac9aa474e9ef78cd8c5c51a9ca6ce6b4fb549a61180461da04ce1af4922f`.

## Why the import is not forced through the current text path

`SWAP/MOD_RIA.f90` contains non-UTF-8 bytes. The currently available Git write path is text-oriented. Re-encoding that file to UTF-8 would produce a different B0 byte stream, even though only comments may appear visibly different.

For an immutable audit baseline, silently changing bytes is worse than temporarily leaving the unpacked mirror pending. The archive hash and per-member hashes already provide an exact, reproducible identity.

Once a binary-safe Git import path is available, the source tree can be added and this gate can be closed without changing B0 semantics or the B1 patch model.
