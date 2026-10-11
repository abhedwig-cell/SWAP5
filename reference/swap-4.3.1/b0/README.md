# B0 immutable source reference

This directory defines the byte-preserving SWAP 4.3.1 B0 source baseline.

Start here:

- `SOURCE_IDENTITY.md`: controlling distribution/source/executable identities;
- `file-manifest.sha256`: raw-byte SHA-256 and byte size of all 63 Fortran members;
- `verify_source_archive.py`: executable archive/member integrity check;
- `VERIFICATION_RESULT.md`: recorded successful verification result;
- `ENCODING_NOTES.md`: why text normalization is forbidden for B0;
- `IMPORT_GATE.md`: remaining conditions for an unpacked byte-identical Git mirror.

No defect correction belongs in this directory. B1 corrections are represented under `../patches/` and admitted through `../b1-manifest.yml`.
