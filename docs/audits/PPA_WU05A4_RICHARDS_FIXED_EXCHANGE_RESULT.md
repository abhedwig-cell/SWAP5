# PPA-WU05-A4 first real Richards exchange result

Date: 2026-09-30

Status: `RESEARCH_PASS / REAL_RICHARDS_FIXED_EXCHANGE_GREEN`

Head: `0da844cfac7d0159f3ed7d72b142a7af37846d1c`

Workflow run: `36764661597`

## Purpose

Verify that the existing SWAP5 Richards solver can accept an explicit macropore-to-matrix exchange through the already admitted `source_sink_provider_t` seam without activating the deferred production macropore route.

## Method

A research-only fixed-exchange provider was added under `research/macropore/`.

The probe:

- uses the real `reference_richards_legacy_solver_t`;
- uses the normal Mualem-Van Genuchten constitutive provider;
- keeps `request%physical%macropore_active = .false.`;
- injects one positive internal exchange source at a single matrix node;
- uses the existing fixed top-boundary and Richards request contracts;
- evaluates the full matrix storage balance including the resulting bottom-boundary flux.

## Initial failed assertion

The first probe incorrectly expected:

`Delta matrix storage = macropore exchange amount`.

That is not the full Richards balance because the real solver also adjusts the bottom-boundary flux.

The correct identity is:

`Delta S = (q_bottom - q_top - sinks + sources) * dt`

under the solver sign convention used by the explicit source/sink route.

The test was corrected to use this full balance rather than weakening any tolerance.

## Result

The corrected probe:

- compiled at O0 and O2;
- converged in the real Richards solver;
- satisfied the full storage/boundary/source-sink balance within the strict probe tolerance;
- exposed the typed integrated solver mass residual;
- passed identically at O0 and O2.

Workflow marker:

`PPA_WU05A4_RICHARDS_GATE=PASS`

## Interpretation

This is the first executable proof in the macropore research line that matrix/macropore internal exchange can be routed through the current SWAP5 Richards infrastructure without modifying HeadCalc physics or activating the historical implicit macropore path.

The useful architecture is therefore:

1. compute macropore candidate exchange outside the Richards kernel;
2. expose that exchange through the generic source/sink provider;
3. let Richards solve the matrix candidate with that exchange;
4. reconcile matrix candidate mass and macropore candidate mass at the transaction layer;
5. accept or reject both atomically.

## Important scope limit

This probe uses a fixed precomputed exchange vector.

It does not yet prove nonlinear two-way exchange where the macropore flux is recomputed from the evolving Richards iterate.

That distinction is intentional. The next research step should test predictor/corrector coupling before attempting fully implicit iteration-dependent exchange.

## Next step

Build an R2 predictor/corrector single-step experiment:

- predictor Richards solve from accepted matrix state;
- source-shaped macropore exchange from predictor matrix state and accepted macropore state;
- corrector Richards solve with fixed exchange vector;
- macropore candidate update with the same exchanged water;
- combined matrix+macropore mass reconciliation;
- compare one corrector versus optional second corrector to assess whether iteration is needed.
