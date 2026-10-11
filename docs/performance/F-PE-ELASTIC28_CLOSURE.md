# F-PE-ELASTIC28 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@e0aead4c1a1402dbcf7aabb18218711383e237d4`

Merged PR:
`#850`

Admitted production file:
`src/adapter/mod_fmr_elastic_storage_request_source_arbitration.f90`

Admitted production blob:
`7d6596bd17b1d06b44698de89f927c60c5bd67ac`

## Admission summary

F-PE-ELASTIC28 admits typed arbitration among externally supplied ELAS
configuration-path candidates without silent precedence.

Rules:
- zero supplied candidates -> inactive;
- exactly one valid supplied candidate -> selected;
- multiple supplied candidates -> conflict, fail closed;
- supplied blank path -> invalid source, fail closed.

Candidate source classes are explicit application, CLI-derived and
environment-derived paths. ELASTIC28 reads none of those external sources.

## Qualification authority

Qualified branch:
`work/f-pe-elastic28-request-source-arbitration`.

Qualified postimage:
`8a791816b9f3393a8db46a7600532f929b4e7e61`.

Result-document head:
`82b823ba256631e9a79d28985377842ea0b3f9b1`.

Qualification:
- workflow run `36583470077`;
- job `109457454727`;
- conclusion SUCCESS.

Passed:
- zero-source inactive semantics;
- each single candidate source;
- all ambiguous multi-source combinations fail closed;
- blank-source fail closed;
- path identity preservation;
- ELASTIC27 inactive/default-off composition;
- ELASTIC27 valid-request composition;
- no ambiguous file access;
- O0/O2 identity;
- exact production source scope.

## Ownership semantics

ELASTIC28 owns source arbitration only.

It does not:
- inspect CLI arguments;
- read process environment;
- discover a default config file;
- inspect file existence or contents;
- retrieve profile/source data;
- perform spatial selection;
- derive or activate ELAS.

ELASTIC27 remains the owner of loading an already selected path.

## Remaining boundary

Still external:
- CLI argument -> typed candidate materialization;
- environment variable -> typed candidate materialization;
- default config discovery if ever admitted;
- any future deliberate precedence policy;
- coordinate/location -> maparea selection;
- automatic soil/profile choice.

## Closure

F-PE-ELASTIC28 is canonically admitted and closed.
