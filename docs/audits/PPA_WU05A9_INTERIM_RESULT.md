# PPA-WU05-A9 interim result — FMR macropore top-input ownership

Date: 2026-10-01

Status: PARTIAL_IMPLEMENTATION / PRODUCTION_BINDING HELD

Baseline: `integration/f-ci-canonical@412592b874111f35404171f223d3f2518bcad32e`

## What is established

The B1.11 source census identifies `QInTopVrtDm` and `QInTopLatDm` as the two external top transfers into the macropore domains. The already migrated standard-domain limiter and redistribution logic consumes these as non-negative domain potentials.

A typed FMR carrier has now been added in `src/runtime/mod_fmr_macropore_top_input.f90`. It carries only the source-owned vertical and lateral macropore rates. It deliberately does not derive them from generic `top_flux`, precipitation, irrigation, snowmelt or runon.

The isolated carrier test passes locally at O0 and O2 with warnings-as-errors, runtime bounds checking and floating-point traps.

## Critical ownership result

Historical source evidence from the SWAP 4.3.1 patch/test material shows that the ponding-layer water balance keeps rain, snow, irrigation and runon as the external inputs and subtracts the integrated macropore top-input terms from the surface system. Consequently, macropore top input is not a second whole-column external input. It is a partition/transfer from the surface authority into macropore storage.

This matters for FMR. The current A8 route treats the Richards solver top flux as an external boundary contribution and has no separate admitted surface owner that can atomically debit the same candidate water when macropore top input is accepted. Directly wiring the new carrier into the A8 limiter would therefore be physically unsafe: it can either double-book external input or create extra macropore storage without the matching surface debit.

## Held production binding

Production binding is intentionally held until one bounded transaction seam exists with these semantics:

- original rain/irrigation/snow/runon forcing is externally booked once;
- accepted macropore top input is debited from the same tentative surface/ponding authority;
- rejected/returned macropore input remains with that surface authority;
- matrix top-boundary exchange owns only the residual amount actually sent through Richards;
- rejected FMR trials publish none of these tentative transfers;
- commit publishes matrix, surface and macropore candidate state atomically.

No mass tolerance change is allowed.

## Scope that remains excluded

Rapid drainage, perched-zone physics, RossFast, dynamic crack-feedback and parallel MultiSWAP remain outside A9.

## Next safe step

A9 continues as a surface-owner integration problem, not as a macropore-rate problem. The next implementation slice must introduce or reuse an explicit tentative surface-water partition receipt before the top-input carrier is connected to the production macropore runtime.
