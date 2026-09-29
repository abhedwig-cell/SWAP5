# F-PE-ELASTIC07 — per-layer input-route source-audit result

Date: 2026-09-29

Status: TYPED_ROUTE_CLEAR_LEGACY_PARSER_PROVENANCE_BLOCKED

## Repository tree audit

The current canonical repository tree contains no raw `readswap.f90` or `MOD_MvG.f90` source that can close the legacy ELAS parser/activation chain.

Relevant in-repository authority is limited to:

- the byte-verified compressed corrected B1.10 `MOD_MvG_functions.f90` source;
- typed SWAP5 constitutive providers;
- legacy port fragments used for numerical compatibility;
- provenance documentation.

The current production Task2 adapter imports `MOD_MvG, only: cofgen, swsophy` from the application build environment and initializes typed hydraulics from `cofgen(:,1:n)`, but the raw producer/parser source for that module is not present in the canonical Git tree.

## What is source-bound

Exact corrected B1.10 authority establishes:

- `cofgen(24) -> elas`;
- rows `22:24` belong to the common supplied parameterized-soil block;
- `sw_use_elas` separately controls whether the elastic branch is used;
- active default-MvG saturated semantics are `theta = theta_s + h*ELAS` and `C = ELAS`.

Therefore ELAS value ownership is source-bound as soil/material data.

## Current SWAP5 seam

Current canonical production Task2 already passes node-local `cofgen(:,1:n)` into the typed hydraulic initializer.

Consequently, after F-PE-ELASTIC05, the minimal application mapping is structurally straightforward:

- an explicit activation signal must map to `enable_elastic_storage`;
- row 24 must map to `specific_elastic_storage_input(:)`.

The value must not be inferred from a global numerical setting.

## Remaining provenance gap

The repository does not currently contain enough exact parser source to prove:

- the original user-facing ELAS keyword;
- the exact producer/lifetime of `sw_use_elas`;
- the parser-side unit declaration;
- whether any legacy validation/range rule applies before `paramvg(24)`;
- whether the historical activation option was exposed identically for every hydraulic model.

This prevents a source-qualified legacy-file parser restoration in this workunit.

## Secondary external-source check

The public SWAP-model/SWAP source at commit `c22bd832ddf3e53e330a552f5e31e74f183362d1` is useful only as secondary evidence.

Its `src/io/readswap.f90` fills `paramvg(1:21)` in the inspected parameterized-soil block and does not contain the ELAS/`sw_use_elas` route found in the corrected repository oracle. Therefore it does not close the legacy ELAS parser provenance and must not be substituted for the byte-qualified B1.10 authority.

## Decision

Two routes are distinguished.

### Typed SWAP5 route

Not blocked.

ELAS can be exposed through a future typed soil/material API as:
- explicit active flag;
- per-layer/per-node value in `1/cm`.

This is consistent with the qualified constitutive semantics and does not require reconstructing a legacy keyword.

### Legacy-file compatibility route

Blocked on exact parser provenance.

Do not invent a keyword or infer activation from a nonzero row-24 value.

## Next step

After F-PE-ELASTIC05 production qualification, choose one bounded successor:

1. typed API/input-object exposure first, leaving legacy-file syntax unchanged; or
2. acquire the exact corrected B1.11 parser/application source and restore the historical file route byte-semantically.

For the SWAP5 architecture the first route is cleaner and preserves the intended soil-parameter ownership without creating undocumented legacy syntax.
