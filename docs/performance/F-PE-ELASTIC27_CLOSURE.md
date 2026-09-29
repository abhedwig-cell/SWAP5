# F-PE-ELASTIC27 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@b25db3f198713b6f4ff3b3635b2dca1198763bf6`

Merged PR:
`#847`

Admitted production file:
`src/adapter/mod_fmr_elastic_storage_application_request_loader.f90`

Admitted production blob:
`f5c114c277b62c27851ba2b592d5e1c49d45ab16`

## Admission summary

F-PE-ELASTIC27 admits explicit caller-owned config-path composition:

`explicit config path`
-> ELASTIC26 file adapter
-> ELASTIC25 typed request semantics
-> typed `generated_prior_requested`.

An empty path remains inactive. ELASTIC27 performs no implicit path discovery.

## Qualification authority

Qualified branch:
`work/f-pe-elastic27-application-request-loader`.

Qualified postimage:
`1b96f54285ca3ecc22f70bab43c81927035fb00f`.

Result-document head:
`79db80a9574ac253100990d4e72d0a2f58b8c2b9`.

Qualification:
- workflow run `36571300637`;
- job `109415699351`;
- conclusion SUCCESS.

Passed:
- empty-path inactive semantics;
- valid explicit request path;
- missing-file fail closed;
- ELASTIC26 rejection provenance;
- ELASTIC25 rejection provenance;
- ELASTIC15 default-off identity;
- valid generated-prior application;
- explicit/user ELAS ownership preservation;
- O0/O2 identity;
- exact production source scope.

## Ownership semantics

ELASTIC27 owns only orchestration of an already explicit config path.

It does not:
- discover a default file;
- read environment variables;
- inspect CLI arguments;
- choose a soil/profile;
- perform coordinate/maparea selection;
- retrieve BOFEK/BRO data;
- derive ELAS;
- bind values into runtime parameters.

ELASTIC26 retains file grammar ownership.
ELASTIC25 retains request semantic ownership.
ELASTIC15 retains generated-prior binding and explicit/user conflict authority.

## Remaining boundary

Still external:
- config discovery policy;
- CLI/environment/file precedence;
- coordinate/location -> maparea selection;
- automatic soil/profile selection;
- automatic request from soil identity.

## Closure

F-PE-ELASTIC27 is canonically admitted and closed.
