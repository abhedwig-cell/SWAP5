# F-PE-ELASTIC44 — application-host request-to-row binding preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_IMPLEMENTATION

Baseline:
`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

Work branch:
`work/f-pe-elastic44-application-host-binding`

Parent authority:
- `F-PE-ELASTIC31_CLOSURE.md`;
- `F-PE-ELASTIC37_CLOSURE.md`;
- `F-PE-ELASTIC41_CLOSURE.md`;
- `F-PE-ELASTIC_RD_CHAIN_CLOSEOUT_2026-09-29.md`.

## Purpose

Add one bounded application-host adapter that composes the already admitted
application request discovery and row-file binding seams:

`explicit/CLI/environment config source`
-> ELASTIC31 request discovery
-> typed `generated_prior_requested`
-> explicit ELASTIC33 row-interchange path supplied by the caller
-> ELASTIC37 row application binding
-> prepared SWAP physical-parameter postimage.

The adapter is an application/pre-run composition seam. It is not a solver,
preprocessor, GIS owner, file-discovery policy, or public end-user CLI.

## Required behavior

A1. With no discovered request, return the base parameter object bit-identically
and do not require or read the row file.

A2. With a valid explicit generated-prior request and a valid explicit row file,
produce exactly the same bound parameter postimage as direct ELASTIC31 +
ELASTIC37 composition.

A3. CLI-only and environment-only request discovery retain ELASTIC31 semantics
and produce the same bound postimage as explicit discovery.

A4. Conflicting request sources fail closed before row binding and preserve the
base parameter postimage.

A5. Request/config rejection fails closed before row binding and preserves the
base parameter postimage.

A6. A valid generated-prior request with a missing or invalid row file propagates
ELASTIC37 rejection and preserves the base parameter postimage.

A7. Explicit/user ELAS ownership remains ELASTIC15 authority and cannot be
silently overwritten.

A8. O0/O2 outputs are identical for the qualification fixture.

A9. The existing F-APP01 model-selection host contract remains unchanged.

A10. No spatial selection, CRS transformation, GeoPackage access, subprocess
execution, live network access, or Richards/runtime source discovery is added.

## Interface boundary

The new adapter may accept:
- an explicit ELASTIC application-request config path, possibly blank;
- an explicit ELASTIC33 row-interchange path, possibly blank while inactive;
- a caller-owned base `fmr_b110_physical_parameters_t`.

It returns:
- a prepared/bound parameter object;
- diagnostics preserving both discovery and row-binding status.

The adapter may invoke only admitted typed seams. It must not reinterpret their
status values or introduce precedence.

## Preserved policy

Unchanged:
- generated ELAS remains default OFF;
- explicit/user ELAS has higher ownership;
- automatic generated prior assignment remains MINERAL-only;
- PEAT, ORGANIC_RICH_NONPEAT and UNKNOWN remain non-automatic;
- `h_ref = -100 cm`;
- ELASTIC11 M1 coefficients unchanged;
- uncertainty factor `2.123968031921196`;
- no network I/O in Richards/runtime;
- no spatial ownership in solver/runtime;
- no CRS dependency.

## Admission boundary

A green ELASTIC44 admits only typed application-host composition from already
resolved request source(s) plus an already materialized row file into prepared
SWAP parameters.

Still external:
- application-host invocation of ELASTIC41 offline RD preprocessing;
- source/output path policy for that preprocessing;
- geographic coordinate -> EPSG:28992 transformation;
- any broad stable public SWAP5 CLI.
