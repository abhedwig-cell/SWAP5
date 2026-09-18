# PUB-GC GMD Code and data availability template

## Status

**TEMPLATE_READY — DO NOT PUBLISH WITH PLACEHOLDERS**

Date: 2026-09-18.

This wording is deliberately conservative. It distinguishes public SWAP5 material from the externally governed historical SWAP 4.3.1 reference distribution and does not assert a licence or DOI that has not yet been governed.

## Draft text

> The SWAP5 source code version used for this study is **<<SWAP5_PUBLICATION_VERSION>>** and is archived at **<<SWAP5_ARCHIVE_DOI_OR_PID>>** under **<<SWAP5_LICENSE_AUTHORITY>>**. The active development repository is the public `abhedwig-cell/SWAP5` repository. Publication-specific machine-readable evidence, experiment definitions, workflow provenance, figure-generation material and supplementary records are included in the archived release **<<OR: archived separately at PUBLIC_REPRODUCTION_ARCHIVE_PID_IF_SEPARATE>>**.
>
> The MODFLOW6 live-coupling experiments reported in this study use MODFLOW 6.8.0; its software provenance should be cited using the final submission reference required for that version.
>
> The historical SWAP 4.3.1 distribution used as an external reference asset is not redistributed through the SWAP5 repository or publication archive. The exact distribution used in the qualification record has SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360` and size 8,959,314 bytes. Hash-anchored and machine-readable evidence derived from this reference asset is retained in the public publication evidence package. Access for editors/reviewers to the historical external asset will be arranged **<<LEGAL/PROJECT-APPROVED ACCESS WORDING>>** where permitted by the controlling distribution terms.

## Fields requiring authority

### <<SWAP5_PUBLICATION_VERSION>>

Source must be a governed SWAP5 release/version authority. Do not substitute an invented semantic version.

### <<SWAP5_ARCHIVE_DOI_OR_PID>>

Source must be the persistent exact-version archive created after the release/version and licence authorities are settled. Do not use the live branch URL as a substitute.

### <<SWAP5_LICENSE_AUTHORITY>>

The upstream SWAP version-4 authority is now verified: the official SWAP project and the exact SWAP 4.3.1 package state LGPL v3 for SWAP version 4, with TTUTIL427.LIB under LGPL 2.1.

This placeholder remains because an explicit SWAP5 publication-archive redistribution/licence declaration is still required. Do not silently promote the upstream statement into a repository-wide legal declaration without that authority.

### <<PUBLIC_REPRODUCTION_ARCHIVE_PID_IF_SEPARATE>>

Resolve only if the publication evidence/scripts are archived separately from the exact software release. If one persistent archive contains both code and publication evidence, remove this field and simplify the wording.

### <<LEGAL/PROJECT-APPROVED ACCESS WORDING>>

Requires the controlling project's/licence authority for the non-redistributed historical SWAP 4.3.1 distribution. Do not promise unrestricted access if it is not authorized.

## Required archive content inventory

At minimum the persistent publication package should preserve:

- exact SWAP5 submission source revision;
- `docs/publication/PUB_GC_COUPLE_MANUSCRIPT_DRAFT.md` or final source manuscript;
- E1–E7 result JSON/CSV records;
- E7 frozen selection and component-domain result;
- F1–F7 source figures;
- numeric figure-generation script;
- Tables T1–T6 evidence package;
- notation/units record;
- supplementary methods/evidence;
- reproducibility manifest;
- claim/evidence and claim-to-sentence audits;
- publication experiment workflows/tests needed to interpret or reproduce the reported controlled cases;
- compiler/runtime dependency notes;
- MODFLOW 6.8.0 provenance;
- exact identity and access restrictions for the external SWAP 4.3.1 reference distribution.

## Final validation

Before submission:

1. all `<<...>>` placeholders must be absent;
2. archive PID/DOI must resolve to the exact governed release;
3. archive version/title must match the manuscript title;
4. licence wording must match the archive metadata;
5. the reproducibility manifest must record the same release/archive identity;
6. external SWAP 4.3.1 wording must not imply redistribution;
7. no code/data statement may imply that E7 MODFLOW windows were executed.


## Verified upstream licence provenance

Official SWAP project source:

`https://swap.wur.nl/faq.html`

Exact external package:

```text
SWAP_4.3.1.zip
SHA-256 2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360
```

Embedded licence statement:

```text
SWAP_4.3.1/license/License.txt
SHA-256 a91468a75fcaf481cc8c214e65574ab9bbcb5e389d3a08d1c651c335214d5a4d
```

This provenance may be cited in internal archival records even while `<<SWAP5_LICENSE_AUTHORITY>>` remains unresolved.
