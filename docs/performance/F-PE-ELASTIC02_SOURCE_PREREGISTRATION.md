# F-PE-ELASTIC02 — official Staringreeks-2018 source acquisition

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_SOURCE_ACQUISITION

Parent: F-PE-ELASTIC01H.

## Purpose

Expand ELAS analysis from four repository archetypes to the complete official Staringreeks 2018 material population without transcribing rounded report-table values into the experiment.

The authoritative target population is:

- B01..B18;
- O01..O18.

BOFEK2020 documents the source file as `StaringReeksPARS_2018.csv`, containing 36 material rows with WCr, WCs, Alpha, Npar, Lambda and Ksfit.

## Source priority

1. official NHI Staringreeks-tool package:
   `https://nhi.nu/documents/224/staringreeks_1.0.0.zip`;
2. exact source file inside that package;
3. report Table 3 only as a human-readable cross-check, not as the machine input.

No rounded transcription is allowed as numerical experiment authority.

## Acquisition requirements

The acquisition job shall:

- download the official zip;
- record SHA-256 and byte size;
- list archive members;
- locate candidate Staringreeks parameter CSV files case-insensitively;
- extract the exact candidate;
- print its SHA-256, byte size, header and row count;
- fail if exactly 36 non-header material rows cannot be established;
- verify the names B01..B18 and O01..O18 occur exactly once.

The external package is evidence input, not committed production data until provenance is frozen separately.

## Next gate

Only after successful acquisition and exact-row validation may F-PE-ELASTIC02A preregister and run the full 36-material ELAS response matrix.
