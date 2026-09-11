# F-TB05 runlog

## Purpose

F-TB05 adopts the already-qualified F-TB04 transaction, restart, determinism and MultiSWAP case bank for continuous qualification against a later exact SWAP5 canonical authority. F-TB04 itself is not rewritten.

## Authorities

- F-TB04 closeout: `85280c6c436a73c211b70996f9a22f4ad6b04f9c`.
- Later exact canonical authority: `d201904a85f3b595e028242978e52c02f5122a09`.
- Canonical `src` tree: `d6f4816be543044b090d11294808b5be986b2ee8`.
- Canonical `reference` tree: `9d08625217d7c0a7385df9da6a04183bcd9cb9e6`.
- Composition baseline: `b38d04632845e2c6c6329eb1b3037d0186172df9`, with current canonical as first parent and F-TB04 closeout as second parent.

The composition retains `src/**`, `reference/**`, current F-CI43 tests/workflows and current canonical integration evidence from `d201904...`. It adds only the F-TB testbank subtree, F-TB documentation/evidence and F-TB workflows from the closed F-TB04 authority.

## Scope boundary

The later canonical adds the restricted soil-temperature capability admitted through F-CI43/F-CI43P. F-TB05 does not infer new restart, MultiSWAP or optional-persistent-state coverage for that capability merely because the earlier F-TB04 bank remains green. Those are explicit nonclaims and require their own runtime/state qualification when materialized.

No production source, reference source, physics, solver or scientific tolerance may be changed by F-TB05. Any source defect is routed to a separate owner workunit.

## Adoption implementation

The original F-TB04 catalog, validators, runners, closeout status and invariant audit remain byte-identical to `85280c6c...`.

F-TB05 adds a separate adoption validator and thin replay wrappers. The wrappers mechanically rebound only the exact canonical commit/source-tree authority in temporary copies of the closed F-TB04 replay machinery. Historical F-TB04 artifacts and scientific/numerical oracles remain immutable.

## Precloseout FAST

Workflow run `34621786809` on head `ff7d9d074cd6f99ffc09c37df7b7b365058e4f5e` concluded FAST `success`.

Observed gates include:

- `FTB05_CURRENT_CANONICAL_AUTHORITY=PASS:d201904a85f3b595e028242978e52c02f5122a09`
- `FTB05_CURRENT_CANONICAL_SOURCE_TREE=PASS:d6f4816be543044b090d11294808b5be986b2ee8`
- `FTB05_CURRENT_CANONICAL_REFERENCE_TREE=PASS:9d08625217d7c0a7385df9da6a04183bcd9cb9e6`
- `FTB05_FTB04_HISTORICAL_AUTHORITY_IMMUTABLE=PASS:85280c6c436a73c211b70996f9a22f4ad6b04f9c`
- `FTB05_FTB04_CASE_CATALOG_BYTE_IDENTITY=PASS:COUNT=35`
- `FTB05_SOIL_TEMPERATURE_NONCLAIM_BOUNDARY=PASS`
- F-TB04 transaction checkpoint/rollback/exactly-once/revision/atomic-restart/optional-state/scratch source gates PASS
- F-TB04 transaction O0/O2 bit identity PASS
- `FTB05_PROFILE_FAST=PASS`

## Closeout rule

F-TB05 is qualified only when the F-TB05 workflow concludes success on the exact status head with both FAST and RELEASE adoption jobs successful. RELEASE must replay the F-TB04 restart, serialized/parallel MultiSWAP, distinct-parameter-reference, deterministic collection, hard-mass and parallel-restart matrices against `d201904...` without changing production source or historical F-TB04 authority.
