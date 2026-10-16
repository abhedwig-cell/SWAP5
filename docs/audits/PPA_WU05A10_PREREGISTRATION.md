# PPA-WU05-A10 preregistration — FMR macropore rapid drainage

Date: 2026-10-01

Status: PREREGISTERED_IMPLEMENTATION_IN_PROGRESS

Baseline: `integration/f-ci-canonical@7db09b56deb99decf32f47d2deed72710a04e8b5`

## Purpose

Extend the canonically admitted A8/A9 serialized single-column Reference-Richards macropore route with the already source-bound B1.11 rapid-drain process.

A10 does not reopen A8 or A9. It binds the qualified A6 multi-compartment `RAPIDDRAIN` implementation to dynamic FMR hydraulic views and accepted external-mass ownership.

## Source authority

PPA-WU05-A6 R4 and A5 P5 establish:

- rapid drainage belongs only to main macropore domain 1;
- activation depends on drain type, active main-domain bottom and drain level;
- conductance is accumulated over the saturated active main-domain compartments;
- the partially saturated top compartment is weighted by its saturated fraction;
- resistance scales with `min(KDCrRlRef/KDCrRl,1.1)`;
- drainable water excludes macropore volume below drain level;
- total drainage is capped by drainable storage;
- compartment drainage sums to one external rapid-drain receipt.

The existing production module `mod_ppa_wu05a6_rapid_drain_rate` is the process authority. A10 shall not duplicate that equation set.

## Bounded first-production scope

Only:

- standard `swmbf=1`;
- serialized single-column FMR;
- Reference Richards;
- main macropore domain 1;
- one explicit rapid-drain topology/configuration;
- drain level aligned to an FMR compartment boundary, so volume below the drain level is reconstructed without interpolation ambiguity;
- dynamic water level, top saturated fraction, current main-domain volume and ponding derived from the accepted trial state;
- one external rapid-drain mass owner.

A9 top input may remain active simultaneously because top input and rapid drainage have distinct external ownership.

## Explicit exclusions

A10 does not admit:

- perched-zone macropore physics;
- arbitrary within-compartment drain-level interpolation;
- multiple rapid-drain levels;
- fixed-weir/Ribasim ownership of the same rapid-drain receipt;
- dynamic crack-geometry displacement feedback inside one corrector;
- RossFast;
- parallel/concurrent MultiSWAP.

Unsupported combinations remain fail-closed.

## Ownership invariants

1. Rapid drainage is an external outflow, never matrix/macropore internal exchange.
2. It is booked exactly once in accepted whole-column mass.
3. Rejected trials publish no rapid-drain receipt and mutate no committed state.
4. Drain topology/resistance parameters are immutable physical configuration.
5. Water level, saturated top fraction, storage and active geometry are dynamic views, not persistent duplicate state.
6. The inner Reference-Richards solve remains `macropore_active=.false.`.
7. A8/A9 disabled and zero-rapid routes remain preserved.

## Qualification plan

Focused tests shall cover:

- source-bound A6 rapid-drain oracle preservation;
- FMR rapid-view reconstruction;
- drain-type/domain-bottom activation gate;
- drainable-storage cap;
- compartment-distributed drainage identity;
- real serialized Reference-Richards trial with nonzero rapid drainage;
- external mass accounting;
- candidate-only publication;
- discard/replay;
- persistence/restart continuation;
- A8/A9 preservation;
- O0/O2 identity.

GitHub Actions is used only for persisted compile/run qualification.

## Exit criteria

- `QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE_FMR_MACROPORE_RAPID_DRAIN`;
- `RAPID_DRAIN_VIEW_RECONSTRUCTION_FALSIFIED`;
- `MASS_OWNERSHIP_FALSIFIED`;
- `TRANSACTIONAL_SEMANTICS_FALSIFIED`;
- or a real blocker.
