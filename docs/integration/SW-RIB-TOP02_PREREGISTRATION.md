# SW-RIB-TOP02 — external-head dynamic-top production candidate

Date: 2026-10-01

Status: PREREGISTERED_IMPLEMENTATION

Baseline:
`integration/f-ci-canonical@0bf4bc0aec1d1f5d157ba6b4a88f0117c854bf6b`

Research authority:
SW-RIB-TOP01 A-E.

## Scope

Implement only the hydraulic external-head part of the qualified TOP01 design.

Production transfer publication is deliberately a separate follow-on gate.

## Preservation rule

When `external_surface_water_head_supplied=.false.`, the dynamic-top provider
must retain current behavior exactly.

## New bounded input

The request gains:

- `external_surface_water_head_supplied`;
- `external_surface_water_head_cm`;
- `external_flooding_sill_head_cm`.

No Ribasim type enters the solver.

## Activation

Strict:

`external_head > sill_head AND external_head > local_candidate_surface_head`.

Equality is inactive.

The existing dynamic-top calculation is first used to determine the local
candidate surface state. Only then may the external flooding override replace
the head candidate. This avoids changing the no-external route.

## Active result

On active flooding:

- regime = HEAD;
- surface head = external head;
- candidate ponding depth = external head for the bounded common datum;
- surface face conductivity = existing saturated top-face conductivity;
- actual top flux uses the existing head-gradient expression;
- runoff depth = 0 for the active flooding candidate;
- route = `external-surface-water-head`;
- head derivative with respect to top-node pressure head follows the existing
  fixed-conductivity head expression when available.

## Holds

- external head must be finite;
- external head/sill datum conversion is caller responsibility in this first
  candidate;
- no snow/macropore admission claim;
- no transfer publication yet;
- no change to F-APP09 subsurface exchange.
