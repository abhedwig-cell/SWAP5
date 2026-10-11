# PUB-GC GMD archive contents inventory

## Status

**PACKAGE_STRUCTURE_READY — FINAL RELEASE METADATA BLOCKED BY A1/A2/A3**

Inventory basis: `a0ee53c48a80dd443d46f60edf08044aeba98273`.

## Packaging rule

The preferred persistent archive is the **complete governed SWAP5 submission revision**, not a hand-picked partial source bundle. This preserves source, contracts, qualification, workflow history and publication evidence together.

The inventory below identifies publication-critical subsets that must be present in that complete archive and checked after deposition.

At the inventory basis the repository contains:

- 2,201 blob files total;
- 107 files under `docs/publication/`;
- 45 files under `tests/publication/`.

These counts are descriptive for the inventory basis, not final release counts.

## Publication-critical content

### Manuscript and supplement

Must include:

- `PUB_GC_COUPLE_MANUSCRIPT_DRAFT.md` or the final source manuscript;
- `PUB_GC_SUPPLEMENTARY_METHODS_AND_EVIDENCE.md`;
- `PUB_GC_NOTATION_AND_UNITS.md`;
- `PUB_GC_MANUSCRIPT_TABLES.md`.

### Evidence and provenance

Retain all PUB-GC E1–E7 preregistration/result records and `docs/publication/evidence/PUB_GC_*`.

Also retain:

- claim/evidence ledger;
- claim-to-sentence audit;
- external reference audit;
- reproducibility manifest;
- submission-readiness audit;
- journal-positioning record;
- GMD archival gate and submission templates.

### Figures

Retain F1–F7 as version-controlled source SVG plus:

- `PUB_GC_FIGURE_EVIDENCE_MANIFEST.json`;
- `generate_pub_gc_numeric_figures.py`.

### Reproduction tests/workflows

Retain the publication E1/E2, E3, E3-D, E3-D2, E3-R and E7 tests/runners and the workflow definitions that generated or preserve their evidence.

The complete repository release naturally retains the lower-level F-GC/PPA/M1 authorities on which those publication tests depend.

## External material excluded from public archive

The historical SWAP 4.3.1 distribution is **not** to be copied into the public archive unless a separate controlling redistribution authority explicitly permits it.

Frozen identity:

- SHA-256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`;
- size: 8,959,314 bytes.

Hash-anchored evidence, manifests and repository-derived qualification records remain in the public archive.

## Final archive validation

After A1/A2/A3 close:

1. verify the archive resolves to the exact governed submission revision;
2. verify every publication-critical surface exists in the deposited revision;
3. update the reproducibility manifest with final version, archive PID/DOI and licence authority;
4. verify title version, archive version and Code/Data wording match;
5. verify no external SWAP 4.3.1 bytes were accidentally deposited;
6. freeze the final archive identity in repository publication governance.

Machine-readable inventory:

`PUB_GC_GMD_ARCHIVE_CONTENTS_INVENTORY.json`.
