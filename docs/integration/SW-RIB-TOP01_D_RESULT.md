# SW-RIB-TOP01-D — classifier and mass-authority reconciliation

Date: 2026-10-01

Status: QUALIFIED_DESIGN_AND_RESEARCH_IMPLEMENTATION

Branch head:
`b6393f2cd7fec1fd4039092240f7924cfd396b8d`

## Corrections completed

TOP01-C's ambiguous legacy publication field has been removed.

The research materializer now exposes separately:

- residual external supply `X`;
- composed legacy `RUNOTS = O-X`;
- closure residual.

Ordinary runoff is therefore represented exactly once.

## Flooding classifier

A pure research classifier now implements the bounded physical branch:

`active = h_ext > h_sill AND h_ext > h_local`.

Tests explicitly cover:

- below sill;
- equality at sill;
- equality at local ponding;
- strict flooding;
- nonfinite fail-closed.

No epsilon changes physical equality.

## Existing canonical mass authority

Current canonical already contains an important compatible contract in
`src/adapter/mod_b1_10_trial_mass.f90`:

- nonnegative runoff is accumulated as `mass%runoff` and total outflow;
- negative runoff is converted to positive `mass%inundation` and total inflow.

Therefore the legacy/reference mass family already represents bidirectional
top-surface exchange as signed runoff/inundation.

This is stronger authority for eventual publication than inferring the sign
from the solver variable `actual_top_flux`.

## Consequence

TOP01 does **not** need a new canonical mass category merely to represent
inundation.

It does need a modern typed candidate transfer because the current dynamic-top
provider only emits nonnegative `runoff_depth` and has no external-head
flooding route.

The target composition is:

1. external hydraulic view classifies flooding;
2. active flooding imposes external surface head;
3. solver returns the soil trial and surface terms;
4. surface control-volume materializer derives `X`;
5. compose signed top exchange `RUNOTS = O-X`;
6. transaction mass publication maps positive RUNOTS to runoff/out and negative
   RUNOTS to inundation/in;
7. coupler books the same accepted transfer in Ribasim with opposite sign.

## Solver-flux sign hold

The production mapping from dynamic solver `actual_top_flux` to positive
surface-to-soil amount `D` remains to be bound from an admitted implementation
path or direct mass test. TOP01-D does not infer it from naming.

This does not block the classifier or control-volume design, but it blocks
production transfer materialization from solver output.

## Research gate

The persisted research runner now covers the mass materializer and strict
flooding classifier. It is not yet compiler-executed on a repository checkout,
so no executable PASS is claimed.

## Next gate

TOP01-E should be a bounded production-readiness experiment, not broad
implementation:

- identify/bind the exact dynamic-top flux sign and accepted surface mass
  publication path;
- implement an external-head research provider/adapter that reuses current
  hydraulic evaluation;
- prove imposed-head soil response and mass decomposition on a minimal
  deterministic fixture;
- then decide whether the production ABI extension is admission-ready.
