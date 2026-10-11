# F-PE-ELASTIC37 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@5be26993a1b4f6c816a6d895d6160a94fa96f158`

Merged PR:
`#873`

Admitted production file:
`src/adapter/mod_fmr_elastic_storage_row_application_binding.f90`

Admitted production blob:
`26e85e8fb2867ffdc31b763d992cbcb6edc9497b`

## Admission summary

F-PE-ELASTIC37 admits explicit application-side composition:

`generated_prior_requested + explicit ELASTIC33 row file + base SWAP parameters`
-> ELASTIC35 row parser
-> ELASTIC22 profile/source-horizon assembly
-> ELASTIC18 grid normalization
-> ELASTIC17 horizon-to-node mapping
-> ELASTIC16 generated-prior assembly
-> ELASTIC15 binding
-> bound parameter postimage.

Request=false remains exact default-off identity and does not require row-file access.

## Qualification authority

Qualified branch:
`work/f-pe-elastic37-row-to-application-binding`.

Qualified postimage:
`221d54958f7d1ffbb88d2ec124f45d16fa39ef37`.

Result-document head:
`13be9f1194993768d4e84b2c022608786f509aac`.

Qualification:
- workflow run `36591248137`;
- job `109484596711`;
- conclusion SUCCESS.

Passed:
- request=false exact identity/no file I/O;
- valid MINERAL generated-prior binding;
- bit-identical manual-parent composition;
- explicit/user ELAS ownership preservation;
- PEAT provenance/rejection;
- missing row-file fail closed;
- invalid SWAP-grid fail closed;
- horizon-straddling node fail closed;
- O0/O2 identity;
- exact production source scope.

## Ownership semantics

ELASTIC37 composes already admitted seams only.

It does not:
- discover a row-file path;
- invoke ELASTIC36 spatial preprocessing;
- choose a maparea/profile;
- create a generated-prior request automatically;
- modify solver/runtime ownership.

ELASTIC15 remains final binding authority and explicit/user ELAS remains higher ownership.

## Remaining boundary

Still external:
- application-host invocation of offline spatial preprocessing;
- automatic handoff from ELASTIC36 output path into ELASTIC37;
- CRS transformation into EPSG:28992;
- any automatic request from location/profile identity.

## Closure

F-PE-ELASTIC37 is canonically admitted and closed.
