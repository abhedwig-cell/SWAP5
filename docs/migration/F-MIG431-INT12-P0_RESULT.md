# F-MIG431-INT12-P0 result

Date: 2026-10-01
Status: CANONICAL_ADMITTED_CLOSED

## Reconciliation

Preregistered branch head began at `83a56f6fa2cb7a6893f9f0f54778fd0618e672f4` from canonical `8bb835a065248aad06b18a3b563234b20033ba0d`.
Before admission, canonical had advanced to `6a2d948e510ddaa4308392051dbba2972b951ae0`. The delta was confined to PPA-WU05 macropore audit/closeout records and did not overlap this work unit's source-window runtime, tests, forcing adapter, restart code, transaction code, mass ledger, or Rutter implementation.

## Falsification of the no-new-code route

The stronger hypothesis that existing canonical infrastructure already supplies the complete SWINTER=1/2 seam is falsified.

PPA-WU03 supplies explicit forcing span bounds and is intentionally stateless. Its admitted envelope is SWINTER=0 and its status explicitly lists SWINTER=1/2 as a nonclaim. It therefore cannot remember accepted partial consumption of a nonlinear source-window aggregate.

FMR Restart v2 serializes committed physical continuation state plus stable runtime identity. It explicitly excludes forcing from physical continuation state. The existing accepted commit receipt identifies the accepted numerical interval, but does not bind that interval to a source-window identity or frozen aggregate.

Therefore a mid-source-window restart cannot reconstruct exactly-once aggregate consumption from current canonical state alone. A small method-neutral continuation seam is necessary. This is runtime provenance/progress, not canopy physical state and not water mass.

## Implemented seam

`src/runtime/mod_interception_source_window_runtime.f90` adds:
- typed positive source-window identity;
- immutable source bounds and frozen aggregate;
- value-type trial apportionment;
- accepted progress represented by the accepted source-window endpoint;
- deterministic cumulative apportionment, with exact aggregate closure at the source-window endpoint;
- explicit accept operation; merely preparing/discarding a trial cannot mutate accepted progress;
- serialization-neutral mid-window restart record.

The module has no dependency on Richards, interception equations, crop, snow, Rutter, FMR mass ledgers, meteorological parsers, or calendar state. It is not wired into method-specific SWINTER=1/2 physics in P0.

## Qualification

PR #965 head `3ef078cb3fe8ca31eea8cdf8515b41620cd87aea`.
Qualification workflow run `36912330400`, job `110537767736`: PASS.

The gate proves:
- arbitrary numerical partition conservation for a frozen aggregate;
- rejected trial leaves accepted progress unchanged;
- failed-then-accepted smaller retry equals the direct retry from the same accepted checkpoint;
- mid-window restart preserves accepted progress and the remaining aggregate exactly;
- final accepted aggregate equals the frozen source-window aggregate bitwise at the endpoint;
- A/B/A replay determinism;
- O0/O2 output identity.

Observed qualified diagnostic:
`final=3.7000000000000000E-01` for frozen aggregate `0.37`.

## Preservation and ownership

No existing production file was modified. PPA-WU01, PPA-WU03, Rutter/SWINTER=3, Richards policy/ABI, mass-ledger semantics and meteorological parsing are therefore outside the production delta. Provenance/progress creates no water-mass booking.

Canonical admission: PR #965 merged as `4d7be05313336e437461f05642affe80bb9bb129`.

## Successor boundary

F-MIG431-INT12-C and F-MIG431-INT12-D may consume this single admitted seam. They must provide their own B1.11 scientific equation oracles and may not independently alter the P0 seam. Successor branch issuance remains with central F-MIG431 governance.
