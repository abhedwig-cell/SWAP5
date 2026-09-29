# F-PE-ELASTIC31 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@90baf88d1671819cade6538e12cdb9df2d61609d`

Merged PR:
`#858`

Admitted production file:
`src/adapter/mod_fmr_elastic_storage_application_request_discovery.f90`

Admitted production blob:
`8b5d23c586c0739919dbe78ed5376f98c0e5a322`

## Admission summary

F-PE-ELASTIC31 admits bounded application-level composition of:

- caller-supplied explicit config path;
- ELASTIC30 CLI-derived config path;
- ELASTIC29 environment-derived config path;

through ELASTIC28 no-precedence arbitration and ELASTIC27 selected-path request
loading.

Zero sources remain inactive. Any ambiguous multi-source combination fails
closed before file loading.

## Qualification authority

Qualified branch:
`work/f-pe-elastic31-request-discovery`.

Qualified postimage:
`0c511aa02dbead13600fb44ccbbf00d0c5f64143`.

Result-document head:
`0b07c5a279b88761e3612b6bf90db3c747c6dd44`.

Qualification:
- workflow run `36586269354`;
- job `109467329327`;
- conclusion SUCCESS.

Passed:
- no-source inactive behavior;
- explicit-only request;
- CLI-only request;
- environment-only request;
- all three pairwise conflicts;
- three-source conflict;
- CLI source rejection provenance;
- environment source rejection provenance;
- selected-path loader rejection provenance;
- O0/O2 identity;
- exact production source scope.

## Ownership semantics

ELASTIC31 defines no new source syntax or precedence policy.

ELASTIC30 owns CLI syntax.
ELASTIC29 owns environment-variable reading.
ELASTIC28 owns source arbitration.
ELASTIC27 owns selected-path request loading.
ELASTIC26 owns config-file grammar.
ELASTIC25 owns request semantics.
ELASTIC15 owns generated-prior binding.

## Remaining boundary

Configuration discovery is now bounded without implicit defaults or precedence.

Still external:
- default config-file discovery, if ever explicitly admitted;
- any future deliberate precedence policy;
- coordinate/location -> BRO maparea selection;
- automatic soil/profile choice;
- end-to-end ingestion of the ELASTIC24 source-profile artifact into typed
  ELASTIC22 horizon rows.

## Closure

F-PE-ELASTIC31 is canonically admitted and closed.
