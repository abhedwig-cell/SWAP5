# PPA-WU05-MIGMAC01 preregistration — covering-layer macropore migration

Date: 2026-10-01

Status: `PREREGISTERED_SOURCE_RECONCILIATION`

Baseline:
`integration/f-ci-canonical@6a2d948e510ddaa4308392051dbba2972b951ae0`

Branch:
`research/ppa-wu05-migmac01-covering-layer`

## Purpose

Recover and migrate the SWAP 4.3.1 standard-macropore covering-layer route represented by
`IcTopMp > 1`, without reopening the canonically closed PERCH21 inner-Richards route or
weakening the A9 surface-source ownership contract.

## Existing canonical boundary

A9 deliberately admits only the surface-connected route and fails closed for the covering-layer
route. The current migration gap audit therefore classifies covering-layer physics as MISSING,
not as an implementation defect in the admitted A9 envelope.

## Source authority required before implementation

The official SWAP 4.3.1 package is the primary equation/state authority.

Before production changes, recover from exact 4.3.1 source:

1. definition and lifecycle of `IcTopMp`;
2. geometry used to locate the macropore top below a covering layer;
3. how rain/irrigation/melt/ponding/runon reach or do not reach that top;
4. any matrix infiltration/percolation term that becomes the covering-layer macropore source;
5. domain-area fractions and storage changes at the covered macropore top;
6. exchange terms in/near the covering layer;
7. state variables that must survive reject/retry/restart;
8. interactions with perched topology and rapid drainage.

No equation may be inferred from the surface-connected A9 route merely to make a test pass.

## Authority fixture

Construct the smallest source-backed fixture that proves a real `IcTopMp > 1` state and has:

- explicit matrix and macropore geometry;
- nonzero source into the covered macropore system;
- complete pre/post macropore state;
- whole-column mass terms;
- sufficient timestep context for exact replay.

Prefer an interval extracted from official `cases/3.macroporeflow` if that case activates the
covering-layer route. Otherwise use another official 4.3.1 case. A synthetic fixture is allowed
only after source semantics are fixed and must not become the sole scientific authority.

## Gates

G1 source semantics documented with exact source locations;
G2 source-backed covering-layer fixture;
G3 independent SWAP5 process-level replay;
G4 serialized Reference-Richards candidate with accepted-origin immutability;
G5 reject/discard/replay and restart;
G6 whole-column mass closure;
G7 preservation of A9/A10/PERCH21;
G8 production-admission decision.

## Stop rules

Stop with an explicit blocker rather than inventing physics if:

- official source cannot establish the source owner;
- the required physical state has no current SWAP5 ownership contract;
- the official case cannot provide a reconstructable authority interval and no other official case does;
- implementing the route would silently create dual ownership with the matrix top boundary.

No tolerance relaxation and no PERCH21 mutation are permitted.
