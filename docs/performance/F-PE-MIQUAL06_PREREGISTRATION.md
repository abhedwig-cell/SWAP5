# F-PE-MIQUAL06 preregistration — serialized runtime moving-interface manager seam

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_SOURCE_WRITES`

Canonical authority:

`integration/f-ci-canonical@412592b874111f35404171f223d3f2518bcad32e`

Parent research authority:

- MIQUAL05: `QUALIFIED_MIQUAL05_DYNAMIC_TOP_EVENT_WINDOW`;
- Z43F: moving-interface manager capability canonically admitted as explicit opt-in/default-off;
- `LEGACY_NUMERICS` remains production default.

## Purpose

Wire the already-qualified moving-interface manager into the normal serialized-reference SWAP Heritage runtime through a bounded, explicit opt-in execution seam.

MIQUAL06 is runtime integration and preservation, not new moving-interface science.

## Frozen production scope

The manager route is eligible only when all of the following hold:

- normal reference Richards path, not RossFast;
- no macropore runtime;
- no accepted-step directional/trajectory side service;
- no snow;
- no restricted soil-temperature process;
- no Black or Boesten evaporation state;
- no fixed-weir surface-water process;
- no active root extraction;
- no active drainage-response coupling;
- no direct-retention/AHL provider;
- SWKIMPL = 0;
- conductivity mean method = 1;
- bottom mode = fixed flux;
- bottom flux = 0;
- explicit fixed-flux top boundary;
- B110 default MvG hydraulics available;
- source/sink arrays are zero;
- accepted state contains a contiguous saturated tail with a reduced active dimension.

Any violation must select exact full bypass, never an error solely because manager mode was requested.

## Selection contract

Manager activation must require an explicit execution-ready moving-interface numerical profile.

Unconfigured/default runtime behavior must remain byte-for-byte on the existing full Richards route.

No implicit activation from soil state or saturation is permitted.

## Accepted-state and fallback contract

Preserve:

- full-column accepted state as sole physical authority;
- reduced request/workspace as reconstructible scratch;
- no accepted-state mutation by failed reduced trials;
- full-shape rematerialization before candidate publication;
- exact full fallback on reduced failure;
- exact full bypass when ineligible;
- existing transaction/commit/rollback authority outside the manager.

## Reconstruction contract

For the initial bounded production seam:

- qbot = 0 only;
- reconstructed saturated-tail pressure heads follow the already-qualified zero-flux hydrostatic/gravity continuation;
- reconstructed tail water contents use node-specific saturated water content from the full B110 hydraulic parameter set.

No fitted correction, mass redistribution or hysteresis is authorized.

## Diagnostics

Expose at least:

- manager requested/enabled;
- route: reduced / full fallback / full bypass;
- full node count;
- reduced active node count;
- fallback/bypass reason.

Existing solver diagnostics and trial outcome accounting remain authoritative.

## Qualification gates

Require focused verification of:

1. default/unconfigured backend still uses full Richards;
2. explicit execution-ready manager profile enables the manager seam;
3. eligible saturated-tail case uses reduced dimension;
4. reduced candidate is rematerialized to full shape before publication;
5. physical state matches the existing full route under frozen gates;
6. forced/ineligible case selects exact full bypass/fallback;
7. failed reduced attempt does not mutate accepted origin;
8. optional-process and unsupported-boundary configurations bypass manager cleanly;
9. existing focused serialized-reference smoke remains green.

## Performance gate

MIQUAL06 is an integration seam, not the final throughput benchmark.

Record deterministic reduced/full work where available, but do not require a wall-clock threshold for admission of the seam.

A separate MIQUAL07 end-to-end benchmark is authorized only after MIQUAL06 passes.

## Frozen classifications

- `QUALIFIED_MIQUAL06_SERIALIZED_RUNTIME_SEAM`
- `MIQUAL06_RUNTIME_RECONCILIATION_CONFLICT`
- `MIQUAL06_MANAGER_SELECTION_FAILED`
- `MIQUAL06_PHYSICAL_MISMATCH`
- `MIQUAL06_FALLBACK_OR_ROLLBACK_FAILED`
- `MIQUAL06_REGRESSION_FAILED`

## Stop rules

Do not:

- broaden the eligible process envelope after source exposure;
- make manager mode default;
- alter manager physics;
- alter numerical tolerances to obtain a pass;
- modify unrelated runtime paths;
- claim whole-SWAP speedup.

## Positive consequence

A positive result authorizes:

`F-PE-MIQUAL07 — production-shaped end-to-end LEGACY vs moving-interface runtime benchmark`.

## Production boundary

`LEGACY_NUMERICS` remains production default.
