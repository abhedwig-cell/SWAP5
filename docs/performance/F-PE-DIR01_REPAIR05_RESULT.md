# F-PE-DIR01 Repair05 result

Date: 2026-09-26

Status: `QUALIFIED_KEEP`

Repair:
fused exact default-MvG base conductivity value + directional constitutive evaluation.

Production scope:
- `src/solver/mod_b110_default_mvg_provider.f90`;
- `src/solver/mod_b110_default_mvg_directional_provider.f90`;
- `src/adapter/mod_reference_richards_accepted_step_directional_service.f90`.

The direct-retention directional route is intentionally unchanged.

## Exact mechanism

Before Repair05, the default-MvG accepted-step directional route performed:

1. a standalone `evaluate_demand(...CONDUCTIVITY...)` pass at the accepted-step base pressure head;
2. a separate exact directional constitutive pass over the same nodes.

Repair05 exposes the existing exact `b110_hconduc` helper and allows the directional provider to return the exact base conductivity while computing the exact water-content and conductivity directions in the same smooth-branch node loop.

No physical solve equation, accepted candidate, transaction ownership or derivative definition is changed.

## Constitutive equivalence

A 12-case production matrix was qualified:

- B01 wet / mid / dry;
- B12 wet / mid / dry;
- O05 wet / mid / dry;
- O14 wet / mid / dry.

For every case:

- fused base conductivity K is bit-identical to the existing default-MvG value provider;
- water-content direction is bit-identical to the pre-Repair05 directional provider;
- conductivity direction is bit-identical to the pre-Repair05 directional provider;
- smooth-route availability and route semantics are preserved.

All reported maximum differences were exactly zero.

The optional fused K output was also omitted in a compatibility call and existing caller semantics remained valid.

## Mechanistic call-count evidence

Pre-Repair05 gprof attribution on a 500,000-interval workload showed approximately:

- Reference `b110_default_mvg_evaluate_demand`: 1,500,306 calls;
- directional: 3,000,603 calls.

That is approximately three extra value-provider calls per directional application interval, matching full + half + half accepted-step execution.

On the Repair05 production postimage:

- Reference `b110_default_mvg_evaluate_demand`: 1,500,303 calls;
- directional: 1,500,303 calls.

The additional directional value-provider pass has therefore been removed, rather than merely becoming cheaper.

## Runtime evidence

Independent paired timing runs were consistently speed-positive.

Pre-production experiment examples:
- mean ratio `0.952041209`, median `0.950102020`;
- mean speedup `4.80%`, median `4.99%`.

Independent experiment:
- mean ratio `0.938445165`, median `0.941892178`;
- mean speedup `6.16%`, median `5.81%`.

Production-postimage comparison:
- mean ratio `0.969825260`;
- median ratio `0.969277789`;
- mean speedup `3.02%`;
- median speedup `3.07%`;
- all ten paired ratios were below 1.0.

Interpretation:
hosted-runner timing varies, but all qualified aggregate runs are positive. A defensible planning range is approximately `3-6%` directional interval speedup, with no claim that the individual percentages are additive to earlier repairs.

## Existing trajectory preservation

The current Repair05 postimage passes:

- FKT22 production compile gate;
- FKT22 production runtime O0;
- FKT22 production runtime O2;
- O0/O2 identity;
- default-off preservation;
- accepted trajectory route;
- accepted-step count;
- accepted backsolve count;
- trajectory provenance;
- rejected-trial isolation;
- physical identity.

The qualified FKT22 bottom-exchange derivative remains:

`0.25`

## Historical hash preservation workflows

Some older F-SI37/F-SI39 preservation workflows reject this branch because they assert exact historical production blob hashes. Those failures are expected after an intentional, separately qualified production edit and are not numerical evidence against Repair05.

Their authorities must be rebuilt at later canonical admission rather than treated as immutable gates against any future exact optimization.

## Decision

Repair05 is retained.

It removes a measured repeated constitutive pass, produces bit-identical constitutive values and directions on the qualified 12-case production matrix, preserves the existing accepted-trajectory runtime contract, and delivers a reproducible exact speedup.

DIR01 must now rebaseline the remaining bottom-head directional overhead on the Repair01 + Repair03 + Repair05 postimage before selecting any further repair.
