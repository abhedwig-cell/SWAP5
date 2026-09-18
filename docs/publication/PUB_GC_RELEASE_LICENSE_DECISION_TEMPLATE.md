# SWAP5 publication release / licence authority decision template

## Purpose

This record defines the **minimum governance decision** required before PUB-GC can create a GMD-compliant persistent software archive.

It is intentionally not pre-filled. The publication workstream has no authority to invent these values.

## Decision A1 — publication release identifier

Required fields:

- governed release/version label: `<<SWAP5_PUBLICATION_VERSION>>`
- exact repository commit to release: `<<RELEASE_COMMIT_SHA>>`
- release class: `<<e.g. publication release / release candidate / other governed class>>`
- authority/approver: `<<AUTHORITY>>`
- decision date: `<<DATE>>`
- versioning rationale or governing policy: `<<RATIONALE_OR_POLICY>>`

Required assertion:

> The identifier above is the authoritative SWAP5 version name that may appear in the PUB-GC manuscript title, archive metadata and Code and data availability statement for the exact commit named above.

## Decision A2 — licence and redistribution authority

Required fields:

- software licence or controlling redistribution terms: `<<SWAP5_LICENSE_AUTHORITY>>`
- scope covered by the licence/terms: `<<SOURCE / DOCS / TESTS / PUBLICATION EVIDENCE / OTHER>>`
- public redistribution of the complete governed SWAP5 release allowed: `<<YES/NO/BOUNDED>>`
- required copyright/notices: `<<NOTICES>>`
- authority/approver: `<<AUTHORITY>>`
- decision date: `<<DATE>>`
- legal/project reference if applicable: `<<REFERENCE>>`

Required assertion:

> The authority above explicitly governs redistribution of the SWAP5 publication release. It is not inferred from GitHub visibility or from the historical SWAP 4.3.1 distribution.

## Historical SWAP 4.3.1 boundary

This decision does **not** automatically authorize redistribution of the historical SWAP 4.3.1 distribution.

Frozen external asset identity:

- SHA-256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`;
- size: 8,959,314 bytes.

Any reviewer/editor access or redistribution rule for that asset must follow its own controlling terms.

## Actions authorized after A1 and A2 are complete

Only after both decisions are explicit may the publication workflow:

1. create the governed SWAP5 release/tag at the approved commit;
2. prepare/finalize archive metadata;
3. deposit the exact release in the persistent archive service;
4. obtain and verify the archive DOI/PID;
5. replace GMD title and Code/Data placeholders;
6. update the reproducibility manifest with release/version/licence/archive identity.

## Non-actions

Completing this template does not itself:

- create a release/tag;
- create a DOI;
- change SWAP5 scientific scope;
- authorize historical SWAP 4.3.1 redistribution unless explicitly stated by its separate authority;
- reopen E7 or any other publication experiment.
