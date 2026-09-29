# F-PE-ELASTIC25 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@ade0dc74638dd3f7e608a55947fdd2e928e883d8`

Merged PR:
`#842`

Admitted production file:
`src/runtime/mod_fmr_elastic_storage_application_config.f90`

Admitted production blob:
`e5f061e261f9aadc1c3d1cd83bce5f096ee24b55`

## Admission summary

F-PE-ELASTIC25 admits the explicit typed application request:

`ELASTIC_STORAGE_SOURCE = GENERATED_BOFEK_BRO_PRIOR`

which produces:

`generated_prior_requested=.true.`

for the already admitted ELASTIC15 generated-prior binding.

Absence remains default OFF.

## Clean qualification authority

Clean branch:
`work/f-pe-elastic25-current-clean-admission`.

Qualified postimage:
`338e7ac75a48e67e9cec654f9f1d5e660b0b1fc9`.

Result-document head:
`19128c4327388a32873ba924c2275ea314955cae`.

Qualification:
- workflow run `36569822749`;
- job `109410742826`;
- conclusion SUCCESS.

Passed:
- default-off request semantics;
- exact explicit request token;
- unsupported key/value fail closed;
- exact-token semantics;
- ELASTIC15 default-off identity;
- valid MINERAL generated-prior application;
- explicit/user ELAS ownership preservation;
- O0/O2 identity;
- exact production source scope.

## Ownership semantics

ELASTIC25 owns request semantics only.

ELASTIC15 remains the owner of:
- generated-prior eligibility;
- MINERAL-only enforcement;
- explicit/user ELAS conflict rejection;
- atomic write into `cofgen(24,:)`;
- `elasticity_active` activation;
- prepared-cache invalidation.

ELASTIC25 therefore cannot silently overwrite explicit/user ELAS and cannot
auto-assign PEAT, ORGANIC_RICH_NONPEAT or UNKNOWN.

## Preserved boundary

Still external:
- file/parser syntax for the application request;
- CLI/environment syntax;
- automatic request from soil identity;
- location-to-maparea spatial selection;
- runtime source-profile acquisition;
- automatic profile selection.

## Current preprocessing/application chain

frozen BRO artifact
-> ELASTIC24 offline explicit-profile retrieval
-> ELASTIC23 typed maparea-to-profile association
-> ELASTIC22 typed explicit profile/source-horizon assembly
-> ELASTIC21/20/19 source descriptor chain
-> ELASTIC18/17 SWAP-grid mapping
-> ELASTIC16 generated-prior assembly
-> ELASTIC25 explicit application request
-> ELASTIC15 binding
-> existing ELAS runtime.

This ordering describes ownership/composition. ELASTIC25 itself performs no
source retrieval or physical derivation.

## Closure

F-PE-ELASTIC25 is canonically admitted and closed.
