# F-PE ELASTIC — RD preprocessing/application chain closeout

Date: 2026-09-29

Status: BOUNDED_CHAIN_CLOSED_WITH_EXTERNAL_CRS_DEPENDENCY_BLOCKER

Canonical authority at closeout:
`integration/f-ci-canonical@c3393aabbc82ee15512250c54464891c84c3d414`

## Scope

This closeout records the ELAS preprocessing/application line developed from
F-PE-ELASTIC22 onward.

The original open boundary was:

- BOFEK/BRO source-profile retrieval;
- profile selection;
- source-horizon materialization;
- application request wiring;
- end-to-end handoff into the admitted ELAS runtime.

For already-resolved EPSG:28992 coordinates, that boundary is now closed.

## Canonically admitted chain

### Source/profile side

- ELASTIC22:
  exact in-memory `normalsoilprofile_id` selection and typed source-horizon
  assembly.
- ELASTIC23:
  exact typed BRO maparea -> normalsoilprofile association.
- ELASTIC24:
  frozen local BRO GeoPackage -> explicit source profile JSON.
- ELASTIC33:
  ELASTIC24 JSON -> canonical nine-field ELASTIC22 row interchange.
- ELASTIC34:
  offline EPSG:28992 RD point -> exact BRO maparea selection.
- ELASTIC35:
  application-side Fortran parser from canonical row interchange to exact
  ELASTIC22 row objects.
- ELASTIC36:
  offline RD point -> maparea -> profile -> canonical row interchange.

### Application-request side

- ELASTIC25:
  explicit typed generated-prior request semantics.
- ELASTIC26:
  bounded local request-file adapter.
- ELASTIC27:
  explicit selected-path request loader.
- ELASTIC28:
  source arbitration with no silent precedence.
- ELASTIC29:
  environment source `SWAP5_ELASTIC_STORAGE_CONFIG`.
- ELASTIC30:
  CLI source `--elastic-storage-config=<path>`.
- ELASTIC31:
  application-level explicit/CLI/environment discovery composition.

### ELAS binding side

Existing admitted authority remains:

- ELASTIC19/20/21:
  horizon classification, frozen Staringreeks catalog and block projection;
- ELASTIC18/17:
  SWAP-grid normalization and horizon-to-node mapping;
- ELASTIC16:
  generated-prior assembly;
- ELASTIC15:
  explicit generated-prior application binding;
- ELASTIC09/08/05:
  production bootstrap, runtime materialization and constitutive ELAS semantics.

ELASTIC37 admits direct application-side composition from an ELASTIC33 row file
through the existing typed chain into the bound ELAS parameter postimage.

ELASTIC41 admits request-gated offline RD preprocessing and explicit row/provenance
handoff.

## End-to-end qualification

F-PE-ELASTIC42 provides research-only end-to-end evidence for the already
admitted chain.

Qualified workflow:
- run `36595018035`;
- job `109497569153`;
- conclusion SUCCESS.

Observed gates:
- frozen source/hash authority: PASS;
- 260 deterministic real-source mineral candidates;
- ELASTIC36 interchange equals direct ELASTIC24+33 materialization: PASS;
- explicit application request: PASS;
- real profile application binding: PASS;
- finite positive generated priors: PASS;
- default-off identity: PASS;
- explicit/user ELAS ownership preservation: PASS;
- O0/O2 identity: PASS;
- zero `src/**` changes.

Selected deterministic successful case in both O0 and O2:
- `normalsoilprofile_id = 90116260`;
- maparea `V2025-1..soilarea.0000003954`;
- RD x `179362.75550490862` m;
- RD y `418659.84937244334` m.

Therefore the following chain is demonstrated:

`explicit EPSG:28992 RD point`
-> frozen BRO maparea/profile selection
-> exact source horizons
-> canonical row interchange
-> explicit generated-prior request
-> ELASTIC37 application composition
-> positive node-local ELAS values
-> ELAS active postimage.

## Preserved physical/application policy

Unchanged:

- generated ELAS is default OFF;
- explicit/user ELAS has higher ownership and cannot be overwritten;
- generated automatic prior assignment is MINERAL-only;
- PEAT is not auto-assigned;
- ORGANIC_RICH_NONPEAT is not auto-assigned;
- UNKNOWN is not auto-assigned;
- `h_ref = -100 cm`;
- ELASTIC11 M1 coefficients remain unchanged;
- uncertainty factor remains `2.123968031921196`;
- no soil-property fitting or ELAS fitting was introduced in this preprocessing
  chain;
- no network I/O was introduced in the Richards runtime.

## Spatial/CRS boundary

The remaining user-location boundary is geographic coordinates to
EPSG:28992 RD coordinates.

Three dependency-free routes have been explicitly tested and falsified on the
standard GitHub runner:

- ELASTIC38: Python `pyproj` route unavailable;
- ELASTIC39: PROJ `cs2cs` route unavailable;
- ELASTIC40: GDAL `gdaltransform` route unavailable.

ELASTIC40 therefore establishes a real dependency/governance blocker.

This is not a failure of the RD-point ELAS chain. The complete RD-coordinate
route is qualified.

## What must happen before geographic-coordinate support

A future workunit must first make an explicit dependency/governance decision,
for example:

- admit a pinned CRS transformation library/dependency;
- admit an external application-host CRS service;
- or require callers to supply EPSG:28992 coordinates.

The choice must be preregistered before implementation. It must not be hidden
inside the Richards runtime or silently introduced through an unpinned external
dependency.

## Current closure decision

For explicit EPSG:28992 RD coordinates:

`CLOSED_ADMITTED_AND_END_TO_END_QUALIFIED`.

For geographic-coordinate -> RD transformation:

`BLOCKED_PENDING_EXPLICIT_CRS_DEPENDENCY_GOVERNANCE_DECISION`.

No additional ELAS physics work is required to close the original ELASTIC22
source-profile/application-request boundary.
