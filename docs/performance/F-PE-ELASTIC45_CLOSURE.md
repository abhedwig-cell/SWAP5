# F-PE-ELASTIC45 — post-admission closure

Date: 2026-09-29

Status: CLOSED_ADMITTED

Canonical admission:
`integration/f-ci-canonical@fb546d243c1a18481c37e5c5aa0e61d37347c95d`

Merged PR:
`#889`

Admitted production file:
`src/adapter/mod_fmr_elastic_storage_rd_application_host.f90`

Admitted production blob:
`6d8451e803277acaedb814579087fe99b247231c`

## Admission summary

F-PE-ELASTIC45 admits the smallest application-host orchestration seam above the
already admitted ELAS source/request/application chain:

`ELASTIC31 request discovery`
-> inactive exact identity/no preprocessing
or
-> active caller-owned EPSG:28992 preprocessing callback
-> admitted ELASTIC41 offline row/provenance handoff
-> admitted ELASTIC44 application preparation
-> prepared SWAP physical-parameter postimage.

The production host owns callback sequencing only. It does not own Python,
subprocess execution, GeoPackage parsing, GIS, CRS transformation, source
selection physics, or ELAS derivation.

## Qualification authority

Qualified branch:
`work/f-pe-elastic45-rd-host-orchestrator`.

Qualified production/test postimage:
`443b372ea18caf702d898d1e0c3907ccf23bc200`.

Result-document head at admission:
`b49b71fa9c6dc468135addf968dc172d69cfd4f6`.

Qualification:
- workflow run `36612484295`;
- job `109557133703`;
- conclusion SUCCESS.

Passed:
- inactive exact base-parameter identity with preprocessing callback count zero;
- one active request invokes preprocessing exactly once with exact RD/source/output arguments;
- real admitted ELASTIC41 preprocessing against the frozen BRO artifact;
- ELASTIC41 output consumed through admitted ELASTIC44;
- active finite positive generated ELAS for the real MINERAL qualification case;
- ELASTIC31 source conflict rejected before preprocessing;
- preprocessing callback failure fail closed;
- missing row artifact after nominal preprocessing fail closed through ELASTIC44;
- explicit/user ELAS ownership preserved;
- repeated row/provenance/postimage determinism;
- O0/O2 host-observable identity;
- production source scope restricted to one application adapter.

Frozen source SHA-256 remains:
`f96bea1e9efdd0326ae1ca0d72684cd7928c90fd23f0930b51c782dfc0ff5fe6`.

Qualified real case:
- normalsoilprofile_id `90116260`;
- RD x `179362.75550490862` m;
- RD y `418659.84937244334` m.

## PR-wide check adjudication

PR #889 triggered broad historical/publication workflows in addition to the
work-unit-specific qualification.

Several broad checks reported failure because their own frozen work-unit gates
reject any unrelated `src/**` delta, or because their own standalone compile
source sets are incomplete for current canonical. Those failures did not test
the ELASTIC45 contract and are not reinterpretations of the successful
preregistered ELASTIC45 qualification.

The admission decision therefore rests on the named ELASTIC45 workflow and its
bounded dependency surface, consistent with repository qualification policy.

## Preserved ownership and physical policy

Unchanged:
- generated ELAS remains default OFF;
- explicit/user ELAS has higher ownership;
- generated automatic prior assignment remains MINERAL-only;
- PEAT is not automatically assigned;
- ORGANIC_RICH_NONPEAT is not automatically assigned;
- UNKNOWN is not automatically assigned;
- `h_ref = -100 cm`;
- ELASTIC11 M1 coefficients remain unchanged;
- uncertainty factor remains `2.123968031921196`;
- no network I/O is introduced into Richards/runtime;
- no GIS, GeoPackage or CRS ownership is introduced into solver/runtime;
- no source precedence is introduced;
- no automatic request is created from location or profile identity.

ELASTIC31 remains request-discovery authority.
ELASTIC41 remains concrete offline RD-preprocessing authority.
ELASTIC44 remains request/row application-preparation authority.
ELASTIC15 remains final generated-prior binding and explicit/user ownership
authority.

## Current operational boundary

For callers that already provide EPSG:28992 RD coordinates, the chain is now
closed through an admitted application-host orchestration seam:

`explicit RD point + explicit generated-prior request`
-> frozen BRO source
-> deterministic maparea/profile/source-row preprocessing
-> application-host handoff
-> prepared SWAP parameters with generated ELAS
-> existing admitted ELAS runtime.

The remaining geographic-input boundary is still:

`longitude/latitude`
-> EPSG:28992.

ELASTIC38, ELASTIC39 and ELASTIC40 falsified the three tested dependency-free
routes, and ELASTIC43 established that introducing a CRS dependency requires an
explicit governance decision.

## Closure

F-PE-ELASTIC45 is canonically admitted and closed.

For explicit EPSG:28992 coordinates, there is no remaining non-CRS ELAS
application-host seam identified by this chain.

Geographic-coordinate input remains:
`BLOCKED_PENDING_EXPLICIT_CRS_DEPENDENCY_GOVERNANCE_DECISION`.
