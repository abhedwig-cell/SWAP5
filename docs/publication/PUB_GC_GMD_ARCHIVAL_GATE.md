# PUB-GC GMD archival and release gate

## Status

**BLOCKED_GOVERNANCE_METADATA_NOT_SCIENCE**

Date: 2026-09-18.

Canonical basis at gate creation:

`integration/f-ci-canonical@a0ee53c48a80dd443d46f60edf08044aeba98273`

The PUB-GC scientific core is closed through E7. The current blocker is submission compliance for the selected primary journal, **Geoscientific Model Development (GMD)**, not missing hydrological evidence.

## 1. Governing journal requirement

Current GMD policy requires:

- an exact model version or other unique identifier in the title for model-development papers;
- a persistent public archive with a unique identifier for the precise code version described in the paper;
- a Code and data availability section citing that archive;
- a clear software licence statement;
- preprocessing, run-control and postprocessing scripts covering reported results;
- reviewer/editor access to any associated code/data that cannot be publicly archived for reasons beyond the authors' control.

Official policy checked 2026-09-18:

- https://www.geoscientific-model-development.net/about/manuscript_types.html
- https://www.geoscientific-model-development.net/policies/code_and_data_policy.html
- https://www.geoscientific-model-development.net/submission.html

## 2. Current SWAP5 repository authority

### Scientific/release readiness

The historical Status-A release-readiness authority:

`tests/qualification/status-a-baseline-20260916/STATUS_A_RELEASE_READINESS_BASELINE.md`

records:

`READY_FOR_STATUS_A_RELEASE_CANDIDATE_BOUNDARY`

and explicitly permits creation of a Status-A / release-candidate tag or release authority.

That authority establishes that a release-candidate action is allowed. It does **not** define the publication version identifier, release naming scheme or software licence.

### Current version identifier

No explicit SWAP5 release/version policy or submission version identifier was located on current canonical.

The current publication manuscript therefore must **not** invent a semantic version number merely to satisfy journal formatting.

A Git commit SHA is a unique repository identifier, but using only a development SHA in the final GMD title is inferior to a governed release/version identity and does not replace the persistent archive requirement.

### Current licence authority

The current root `README.md` states:

> The licence files originate from the SWAP 4.3.1 distribution. Repository documentation does not create a separate licensing decision from the SWAP project.

The current repository tree contains no root `LICENSE`, `LICENCE`, `COPYING`, `CITATION.cff`, `.zenodo.json` or equivalent publication-level licence/archive metadata.

This record does **not** conclude that SWAP5 is proprietary or that a particular open-source licence applies. It records only that the current repository does not contain an explicit publication-ready licence authority.

A licence must not be selected or inferred by this publication workstream.

## 3. External historical reference asset

The exact historical SWAP 4.3.1 distribution remains an externally governed reference asset.

Current frozen identity:

- SHA-256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`
- size: `8,959,314 bytes`

It is not redistributed through the SWAP5 repository.

For GMD submission, the Code and data availability statement must distinguish:

1. public SWAP5 code and publication evidence;
2. the external historical SWAP 4.3.1 reference distribution;
3. the reproducible hash-anchored evidence derived from that external asset.

Where legally possible, editor/reviewer access to the external asset should be arranged without changing its redistribution status.

## 4. Archival blockers

### A1 — release/version authority

**BLOCKED_GOVERNANCE_DECISION**

A controlled authority must define the SWAP5 publication release identifier or version label.

The publication workstream may not invent this value.

### A2 — software licence authority

**PARTIALLY RESOLVED — UPSTREAM SWAP 4 LICENCE VERIFIED / SWAP5 ARCHIVE DECLARATION STILL BLOCKED**

A2 is now split into two authority layers.

**A2a — upstream/historical SWAP 4 licence: VERIFIED.**

The official SWAP project states that SWAP version 4 is distributed under the **LESSER GNU GENERAL PUBLIC LICENSE version 3**, with TTUTIL427.LIB under LGPL 2.1. The exact SWAP 4.3.1 distribution used by this repository contains the same licence statement in `license/License.txt`.

Exact embedded licence identities are frozen in `PUB_GC_GMD_RELEASE_LICENSE_AUTHORITY_AUDIT.md`.

**A2b — SWAP5 publication archive licence/redistribution declaration: BLOCKED_GOVERNANCE_OR_LEGAL_DECISION.**

The SWAP5 repository contains substantial modernized and new source and deliberately has no root licence declaration that independently assigns the complete publication archive to a licence. The current README also states that repository documentation does not create a separate licensing decision.

An authorized WUR/WENR/SWAP-project authority must therefore confirm that the SWAP5 publication archive may be distributed under the upstream SWAP version-4 terms, or provide the alternative authorized statement.

The publication workstream will not manufacture that legal declaration.

### A3 — persistent archive / DOI

**BLOCKED_EXTERNAL_ARCHIVE_ACTION**

After A1 and A2b are resolved, the exact submission revision must be archived in a persistent repository with a unique identifier/DOI.

GitHub remains the development repository but is not, by itself, the frozen archive required by current GMD policy.

### A4 — title binding

**BLOCKED_BY_A1**

After the release identifier exists, bind it into the GMD title.

Current template:

> Hydrologically accountable finite-window coupling of SWAP5 (version X) and MODFLOW 6.8.0

Do not replace `X` until A1 is closed.

### A5 — final Code and data availability wording

**BLOCKED_BY_A2B_A3**

The final section must cite:

- exact SWAP5 archive identifier/DOI;
- public reproduction/evidence archive;
- software licence;
- MODFLOW 6.8.0 provenance;
- external SWAP 4.3.1 restrictions and exact identity.

## 5. Already closed submission prerequisites

The following do **not** block archival preparation:

- scientific RQ1–RQ5: closed/bounded;
- E7: `CLOSED_REALISTIC_COMPONENT_DOMAIN_LIMIT`;
- manuscript core: consolidated through E7;
- Figures F1–F7: built;
- Tables T1–T6: built;
- claim-to-sentence audit: PASS;
- reference metadata audit: complete;
- notation/units package: ready;
- journal target: GMD / Development and technical paper;
- GMD short summary candidate: prepared;
- exact current repository/evidence provenance: machine-readable.

## 6. Prepared submission templates

The work that does not depend on A1/A2 has been persisted:

- `PUB_GC_GMD_SUBMISSION_METADATA_DRAFT.md` — title/version placeholder, 432-character short summary, key figure, keywords, author/contribution/funding placeholders and claim guard;
- `PUB_GC_GMD_CODE_DATA_AVAILABILITY_TEMPLATE.md` — conservative Code and data availability wording with unresolved version, DOI, licence and historical-asset access fields.

These templates deliberately expose unresolved authority rather than hiding it.

## 7. Permitted work before governance resolution

The publication workstream may continue with:

- GMD formatting preparation;
- author/affiliation placeholder structure;
- final reference-style conversion;
- figure export preparation;
- cover-letter draft;
- archive contents inventory;
- Code and data availability template with unresolved fields clearly marked.

It must **not**:

- choose a SWAP5 version number;
- choose or assert a software licence;
- claim that a DOI/archive exists;
- redistribute the historical SWAP 4.3.1 asset;
- change scientific evidence to compensate for archival blockers.

## 8. Closure rule

This gate closes only when all of the following are true:

1. a governed SWAP5 publication version/release identifier exists;
2. the SWAP5 publication-archive licence/redistribution authority (A2b) is explicit;
3. the exact submission revision and required public assets are persistently archived;
4. the archive has a unique persistent identifier/DOI;
5. the manuscript title and Code/data availability section point to that exact archive;
6. the final archive identity is recorded in the PUB-GC reproducibility manifest.

Until then, the paper is **scientifically ready but not submission-compliant for GMD**.


## Current-canonical preservation note

The GMD journal-positioning merge `a0ee53c48a80dd443d46f60edf08044aeba98273` completed all post-merge preservation gates:

- F-CI canonical qualification run 35377931629 — SUCCESS;
- F-CI51P moving-current preservation run 35377931595 — SUCCESS;
- F-CI58P reconciliation/preservation run 35377931486 — SUCCESS.

The archival gate therefore does not represent an unresolved scientific or canonical-qualification failure.


## 9. Prearchive automation and inventory

The non-governance part of the archive preparation is now frozen in:

- `PUB_GC_GMD_RELEASE_LICENSE_AUTHORITY_AUDIT.md`;
- `PUB_GC_GMD_PREARCHIVE_INVENTORY.json`;
- `PUB_GC_GMD_PRESUBMISSION_CHECKLIST.md`;
- `tools/publication/check_pub_gc_gmd_submission.py`.

The inventory binds the current manuscript, E1–E7 evidence and F1–F7 publication assets by repository blob identity. The checker distinguishes an integrity failure from an intentionally unresolved governance field.

This reduces the remaining archival decision to:

1. A1 release identifier;
2. A2b explicit SWAP5 archive licence/redistribution statement;
3. A3 external persistent archive/PID after 1–2.
