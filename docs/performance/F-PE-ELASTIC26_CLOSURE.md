# F-PE-ELASTIC26 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@bcc15ffaf00b9a5252158da8c1e09c67749248e3`

Merged PR:
`#845`

Admitted production file:
`src/adapter/mod_fmr_elastic_storage_application_config_file_adapter.f90`

Admitted production blob:
`da9ae24465fb43b0122db126c4fb8d82976aaf3e`

## Admission summary

F-PE-ELASTIC26 admits a bounded local file adapter for the typed ELASTIC25
generated-prior application request.

The admitted seam is:

`local config file`
-> typed ELASTIC25 config
-> ELASTIC25 request semantics
-> ELASTIC15 explicit generated-prior binding.

The adapter reads at most one non-empty assignment, with blank lines ignored and
a maximum file size of 4096 bytes.

## Qualification authority

Qualified branch:
`work/f-pe-elastic26-config-file-adapter`.

Qualified postimage:
`23a14c73f370d45d7bcef40204bbea34f81edfc3`.

Result-document head:
`c6f636a3de5afe075eb25efe34e5f3256559ae14`.

Qualification:
- workflow run `36570573952`;
- job `109413253590`;
- conclusion SUCCESS.

Passed:
- exact one-line file materialization;
- blank-line handling;
- empty/missing path fail closed;
- malformed syntax fail closed;
- multiple assignment fail closed;
- oversized file fail closed;
- parser/semantic ownership separation;
- ELASTIC25 composition;
- O0/O2 identity;
- exact production source scope.

## Ownership semantics

ELASTIC26 owns only local file syntax and bounded local file reading.

ELASTIC25 remains the owner of supported application key/value semantics.

ELASTIC15 remains the owner of:
- generated-prior eligibility;
- explicit/user ELAS conflict rejection;
- atomic generated-prior binding;
- ELAS activation;
- cache invalidation.

The file adapter therefore cannot itself activate ELAS or override explicit user
ELAS.

## Preserved boundary

Still external:
- automatic config-file discovery;
- CLI/environment precedence;
- automatic generated-prior request from soil identity;
- location/coordinate to maparea selection;
- automatic profile selection;
- runtime source-profile acquisition;
- network I/O in the Richards/runtime path.

## Current chain

frozen BRO artifact
-> ELASTIC24 offline explicit-profile retrieval
-> ELASTIC23 typed maparea-to-profile association
-> ELASTIC22 source-horizon assembly
-> ELASTIC21/20/19 descriptor source chain
-> ELASTIC18/17 SWAP-grid mapping
-> ELASTIC16 generated-prior assembly
-> ELASTIC26 bounded request-file adapter
-> ELASTIC25 typed explicit request
-> ELASTIC15 generated-prior binding
-> existing ELAS runtime.

## Closure

F-PE-ELASTIC26 is canonically admitted and closed.
