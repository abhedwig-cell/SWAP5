# F-PE-ELASTIC45 — RD application-host orchestrator preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_IMPLEMENTATION

Baseline:
`integration/f-ci-canonical@b6c9079c209eb6d1fe2db2fd61ff330941770166`

Parent authority:
- `F-PE-ELASTIC41_CLOSURE.md`;
- `F-PE-ELASTIC44_CLOSURE.md`;
- `F-PE-ELASTIC_RD_CHAIN_CLOSEOUT_2026-09-29.md`.

## Purpose

Close the smallest remaining non-CRS operational seam identified by ELASTIC44:

`application request discovery`
-> when inactive: exact base-parameter identity and no preprocessing
-> when active: caller-owned offline RD preprocessing callback
-> canonical ELASTIC33 row-interchange path
-> admitted ELASTIC44 application preparation
-> prepared SWAP physical-parameter postimage.

The production orchestrator must not own GIS, GeoPackage parsing, Python,
subprocess execution, CRS transformation, or ELAS physics. Those remain outside
the runtime and are supplied through an explicit preprocessing callback.

## Interface

The orchestrator receives:
- explicit application config path, possibly blank;
- already-resolved EPSG:28992 x/y;
- explicit frozen-source path;
- explicit row/provenance output paths;
- caller-owned base physical parameters;
- one explicit preprocessing callback.

The callback receives only caller-owned preprocessing inputs and returns a
bounded status. It does not receive solver/runtime state.

The orchestrator:
1. uses ELASTIC31 request discovery;
2. returns inactive without invoking the callback when no request is active;
3. invokes the callback exactly once when a generated prior is requested;
4. on callback success, invokes admitted ELASTIC44 with the produced row path;
5. preserves the base parameter postimage on all failures.

## Ownership and invariants

Preserve:
- generated ELAS default OFF;
- explicit/user ELAS higher ownership;
- MINERAL-only generated-prior eligibility;
- PEAT, ORGANIC_RICH_NONPEAT and UNKNOWN non-automatic;
- h_ref = -100 cm;
- ELASTIC11 M1 coefficients unchanged;
- uncertainty factor 2.123968031921196;
- no network I/O in Richards/runtime;
- no GIS/GeoPackage/CRS ownership in solver/runtime;
- no hidden request precedence;
- caller-owned explicit source/output paths.

ELASTIC41 remains the admitted concrete offline RD preprocessor.
ELASTIC44 remains typed request-to-row application preparation authority.
ELASTIC15 remains final generated-prior binding authority.

## Qualification matrix

A1. No request: exact base-parameter identity and preprocessing callback call
count = 0.

A2. Valid explicit request: callback call count = 1 and its exact RD/source/output
arguments are preserved.

A3. Qualification callback invokes the real admitted ELASTIC41 tool against the
frozen BRO artifact and produces byte-identical ELASTIC41 row/provenance output.

A4. Resulting row path composes through admitted ELASTIC44 to active finite
positive generated ELAS for a real MINERAL profile.

A5. ELASTIC31 multi-source conflict fails closed before callback invocation and
preserves base parameters.

A6. Callback failure fails closed, leaves no accepted generated-prior postimage,
and does not invoke row binding.

A7. ELASTIC44 binding failure propagates fail closed and preserves base
parameters.

A8. Explicit/user ELAS ownership remains preserved.

A9. Repeated valid composition is deterministic and O0/O2 host-observable output
is identical.

A10. Production source scope is restricted to the application/adapter
orchestrator. No solver/process/legacy/Richards source mutation.

## Admission boundary

A green ELASTIC45 admits application-host orchestration for an explicit
EPSG:28992 RD point and caller-owned offline preprocessing callback.

It does not admit:
- longitude/latitude input;
- a CRS dependency;
- subprocess execution as production ownership;
- automatic generated-prior request creation;
- live PDOK/BRO access;
- runtime GIS/GeoPackage access;
- new ELAS physics;
- a broad public CLI.
