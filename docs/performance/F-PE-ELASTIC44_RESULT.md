# F-PE-ELASTIC44 — application-host request-to-row binding result

Date: 2026-09-29

Status: QUALIFIED_ADMISSION_CANDIDATE

Branch:
`work/f-pe-elastic44-application-host-binding`

Qualified postimage:
`32c2a72410fe0fd2078333dedaa6efa7d4dc385d`

Baseline:
`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

Workflow run:
`36608031416`

Job:
`109541985535`

Conclusion:
SUCCESS.

## Qualified seam

`explicit/CLI/environment ELAS request source`
-> ELASTIC31 request discovery
-> typed generated-prior request
-> explicit ELASTIC33 row-interchange path
-> ELASTIC37 row application binding
-> prepared SWAP physical-parameter postimage.

The new adapter is:
`src/adapter/mod_fmr_elastic_storage_application_host_binding.f90`.

## Qualification

- A1 absent request returns exact base-parameter identity without row-file access: PASS;
- A2 explicit request produces the same postimage as direct ELASTIC31 + ELASTIC37 composition: PASS;
- A3 CLI-only request composition: PASS;
- A3 environment-only request composition: PASS;
- A4 multi-source conflict fails closed before row binding: PASS;
- A5 invalid request/config fails closed before row binding: PASS;
- A6 missing row file propagates ELASTIC37 rejection and preserves base parameters: PASS;
- A7 explicit/user ELAS ownership remains preserved: PASS;
- A8 O0/O2 qualification output identity: PASS;
- A9 admitted F-APP01 minimal application-host contract preserved: PASS;
- A10 no solver/process/legacy source scope: PASS.

## Ownership

ELASTIC44 owns only typed pre-run composition.

It does not:
- discover or invoke ELASTIC41 spatial preprocessing;
- choose RD coordinates;
- access a GeoPackage;
- transform CRS;
- invoke subprocesses;
- add network access;
- alter solver/runtime state ownership;
- introduce a public SWAP5 CLI.

ELASTIC31 retains request-source discovery and no-precedence arbitration.
ELASTIC37 retains row-file application binding.
ELASTIC15 retains final generated-prior eligibility/binding and explicit/user
ELAS ownership.

## Physical policy preserved

Unchanged:
- generated ELAS default OFF;
- MINERAL-only automatic generated prior;
- PEAT, ORGANIC_RICH_NONPEAT and UNKNOWN not auto-assigned;
- `h_ref = -100 cm`;
- ELASTIC11 M1 coefficients;
- uncertainty factor `2.123968031921196`.

## Decision

Classification:
`QUALIFIED_ADMISSION_CANDIDATE`.

The smallest remaining operational seam is application-host orchestration of
the already admitted ELASTIC41 offline RD preprocessing before this typed
ELASTIC44 binding. CRS transformation remains independently blocked by the
ELASTIC43 governance decision.
