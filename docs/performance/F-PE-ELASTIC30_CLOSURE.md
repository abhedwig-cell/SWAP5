# F-PE-ELASTIC30 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@ce19beb11da74139171827731894021bdec51276`

Merged PR:
`#855`

Admitted production file:
`src/adapter/mod_fmr_elastic_storage_cli_source.f90`

Admitted production blob:
`5e6bc5006d08735b81646094cd2a39fc6a0a613d`

## Admission summary

F-PE-ELASTIC30 admits the exact command-line option:

`--elastic-storage-config=<path>`

as the typed ELASTIC28 CLI-derived config-path candidate.

No matching option remains inactive. Duplicate, empty and overlength values fail
closed. Unrelated CLI arguments are ignored.

## Qualification authority

Qualified branch:
`work/f-pe-elastic30-cli-source`.

Qualified postimage:
`5447e96a768d92eada1a975de1662273d81025dd`.

Result-document head:
`67959c79f67f21d76836b7b41d31e8f5eb51620e`.

Qualification:
- workflow run `36585267891`;
- job `109463769152`;
- conclusion SUCCESS.

Passed:
- absent option inactive;
- exact option/path identity;
- unrelated arguments ignored;
- duplicate option fail closed;
- empty value fail closed;
- overlength path fail closed;
- ELASTIC27 request composition;
- CLI+environment conflict preservation;
- O0/O2 identity;
- exact production source scope.

## Ownership semantics

ELASTIC30 owns only fixed CLI syntax and materialization into a typed candidate.

ELASTIC28 remains source-arbitration authority.
ELASTIC27 remains selected-path loading authority.
ELASTIC29 remains environment candidate materialization authority.

No CLI source receives implicit precedence.

## Remaining boundary

Still external:
- composition of explicit application path + CLI + environment discovery;
- default-file discovery, if ever admitted;
- any deliberate future precedence policy;
- coordinate/location -> maparea selection;
- automatic soil/profile choice.

## Closure

F-PE-ELASTIC30 is canonically admitted and closed.
