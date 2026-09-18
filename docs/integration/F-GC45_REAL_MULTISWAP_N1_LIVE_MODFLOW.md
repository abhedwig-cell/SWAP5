# F-GC45 — Real MultiSWAP N:1 live MODFLOW6 application

## Scope

F-GC45 qualifies a real N:1 composition: two independent real FMR/SWAP columns share one live MODFLOW6 6.8.0 groundwater cell. The workunit composes already-admitted production capabilities and does not add new groundwater physics.

The qualified envelope deliberately inherits the short F-GC44 numerical window and plain-water physics: drainage, root extraction, macropores, snow and soil temperature are off; analytic accepted-trajectory tangents only; no runtime finite-difference fallback.

## N:1 predictor construction

Each real FMR tile owns a unique SWAP lineage and produces its own admitted F-GC30 predictor response. The two tiles use different saturated hydraulic conductivities so the predictor responses are physically non-identical without expanding the prescribed-head envelope.

Both predictor responses share one coupling id, groundwater service/lineage/revision and coupling window. Their area fractions are 0.375 and 0.625 and close exactly to one. F-GC40 is the authoritative reduction from the two tile-local affine responses to one common-head groundwater-cell response. F-GC33 then materializes the one MODFLOW API HCOF/RHS term.

## Corrector iteration

MODFLOW6 owns one prepared solve for the entire coupled window. Both SWAP tiles receive the same evolving MODFLOW cell head. Every tile corrector starts from that tile's immutable accepted kernel checkpoint. Non-final candidates from both tiles are discarded before the next iteration.

The coupling residual is the area-weighted real SWAP corrector exchange minus the realized MODFLOW API exchange. The F-GC40 slope stays fixed; only the affine intercept is re-anchored after a non-converged coupling iteration.

Coupled convergence is conjunctive: MODFLOW reports nonlinear convergence and the area-weighted interface-flux residual is within the qualified tolerance.

## Publication

Before the first irreversible operation, the qualification requires publication readiness for both SWAP candidates, both prepared interface ledgers and the live MODFLOW timestep. Publication order is then deterministic: MODFLOW finalize_time_step, both SWAP kernel commits in canonical tile order, then both prepared ledger commits in the same tile order.

Each ledger stores the tile's area-weighted whole-window exchange. Their committed sum must equal the accepted area-weighted SWAP exchange integrated over the window.

## Evidence boundary

F-GC45 proves a real two-column to one-cell N:1 application composition. It is not a scientific claim that arbitrary spatial aggregation is valid. It does not qualify heterogeneous atmospheric forcing studies, larger prescribed-head jumps, active drainage, root uptake, macropores, snow, soil temperature, multiple MODFLOW cells, Ribasim or irrigation.

Predictor/corrector ownership remains inside the internal SWAP5-MODFLOW coupling service below iMOD Coupler.
