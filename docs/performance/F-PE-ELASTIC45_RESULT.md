# F-PE-ELASTIC45 — RD application-host orchestrator result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic45-rd-host-orchestrator`

Qualified postimage:
`443b372ea18caf702d898d1e0c3907ccf23bc200`

Workflow run:
`36612484295`

Job:
`109557133703`

Conclusion:
SUCCESS.

## Qualified seam

`ELASTIC31 request discovery`
-> inactive exact identity/no preprocessing
or
-> active caller-owned EPSG:28992 preprocessing callback
-> admitted ELASTIC41 row/provenance handoff
-> admitted ELASTIC44 application preparation
-> prepared SWAP physical-parameter postimage.

Production code contains no Python, subprocess, GeoPackage, GIS or CRS ownership.
The concrete ELASTIC41 invocation is exercised only by the qualification callback.

## Qualification

- A1 no request -> exact base-parameter identity and callback count zero: PASS;
- A2 active request -> callback exactly once with exact source/RD/output arguments: PASS;
- A3 qualification callback invokes the real admitted ELASTIC41 preprocessing path against the frozen BRO artifact: PASS;
- A4 ELASTIC41 row output composes through admitted ELASTIC44 to active finite positive generated ELAS for the real MINERAL case: PASS;
- A5 explicit + environment request conflict fails closed before preprocessing: PASS;
- A6 preprocessing callback failure fails closed and preserves base parameters: PASS;
- A7 successful preprocessing without a row artifact propagates ELASTIC44 binding rejection and preserves base parameters: PASS;
- A8 explicit/user ELAS ownership conflict remains fail-closed without mutation: PASS;
- A9 repeated valid composition is deterministic and O0/O2 host-observable output is identical: PASS;
- A10 production source scope is limited to `src/adapter/mod_fmr_elastic_storage_rd_application_host.f90`: PASS.

Frozen source artifact:
- producer workflow run `36550782840`;
- artifact `f-pe-elastic12a4-pdok-atom`;
- SHA-256 `f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6`.

Real qualification case retains the already-qualified ELASTIC42 location/profile:
- normalsoilprofile_id `90116260`;
- RD x `179362.75550490862` m;
- RD y `418659.84937244334` m.

## Qualification repair history

Three earlier workflow attempts failed before establishing a negative production result:

1. run `36611562146`: Python fixture-generator quoting syntax;
2. run `36611657663`: remaining fixture-generator quoting syntax;
3. run `36611922788`: negative-test callback reused the valid-source identity assertion;
4. run `36612061016`: O0/O2 negative-test isolation reused a row path created by the earlier optimization run.

Repairs were restricted to qualification fixture mechanics and isolation.
The production orchestrator source was unchanged throughout these repairs.

## Ownership

ELASTIC45 owns only application-host orchestration and callback sequencing.

It does not own:
- CRS transformation;
- GIS or GeoPackage semantics;
- subprocess/Python execution;
- request creation or precedence;
- source-profile selection semantics;
- generated-prior physics;
- final ELAS ownership policy.

ELASTIC31 remains request-discovery authority.
ELASTIC41 remains concrete offline RD preprocessing authority.
ELASTIC44 remains application request/row binding authority.
ELASTIC15 remains final generated-prior and explicit/user ownership authority.

## Decision

Classification:
`QUALIFIED_ADMISSION_CANDIDATE`.

Geographic-coordinate -> EPSG:28992 transformation remains separately blocked by
the ELASTIC43 dependency/governance decision.
