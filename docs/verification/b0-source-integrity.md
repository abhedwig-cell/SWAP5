# B0 source integrity

The SWAP 4.3.1 B0 baseline is treated as byte-preserving historical evidence.

## Recorded identity

The canonical Fortran source archive is identified by SHA-256:

```text
1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151
```

It contains 63 Fortran source members with a total uncompressed size of 1,859,823 bytes.

The repository records the exact raw-byte SHA-256 and byte size of every member in:

```text
reference/swap-4.3.1/b0/file-manifest.sha256
```

The manifest itself is pinned by SHA-256:

```text
d923ac9aa474e9ef78cd8c5c51a9ca6ce6b4fb549a61180461da04ce1af4922f
```

## Verification

`reference/swap-4.3.1/b0/verify_source_archive.py` checks the complete archive hash, manifest identity, exact member set, byte sizes and all member hashes. It has been exercised against the canonical B0 source archive with all 63 members matching.

## Unpacked Git mirror

An unpacked byte-identical Git mirror is still pending. One B0 member, `SWAP/MOD_RIA.f90`, contains non-UTF-8 bytes. A text-only upload path could therefore alter the historical byte stream through encoding conversion.

The project deliberately refuses to call such a normalized copy "B0". The unpacked import will be accepted only through a binary-safe path followed by a full member-manifest check.

This pending import does not weaken the B0 identity: the canonical archive hash and per-member hashes already define the source baseline exactly. It only means that browsing every source file directly inside the Git tree is not yet the authoritative representation.
