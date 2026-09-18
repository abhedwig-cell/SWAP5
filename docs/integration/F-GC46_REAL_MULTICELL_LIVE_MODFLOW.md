# F-GC46 — Real multi-cell live MODFLOW6 application qualification

## Scope

F-GC46 qualifies two independently transactional real FMR/SWAP interfaces coupled 1:1 to two distinct live MODFLOW6 6.8.0 cells in one groundwater model, one timestep and one prepared solve.

This workunit adds no production physics. It is a runtime/composition qualification over already-admitted F-GC30/F-GC34/F-GC41/F-GC44 capabilities.

## Topology

Interface 1 owns SWAP lineage 550045 and groundwater cell 7001. Interface 2 owns SWAP lineage 550046 and groundwater cell 7002. Each interface has its own coupling identity, groundwater lineage and mass ledger. Both share the same live MODFLOW model, timestep and solution.

Each cell uses the F-GC40 single-tile-equivalent path to materialize one affine cell response. F-GC34 publishes the two terms through package slots 1 and 2 to MODFLOW node ids 2 and 3. No N:1 aggregation occurs in F-GC46.

## Coupling loop

MODFLOW6 opens one prepared solve. At every coupling iteration the two current cell heads are supplied separately to the corresponding real FMR/SWAP corrector. Each corrector starts from its own immutable accepted checkpoint. If either interface is not converged, both retained SWAP candidates are discarded and the two affine intercepts are independently re-anchored while their admitted slopes remain fixed.

Convergence is conjunctive: MODFLOW must report nonlinear convergence and both cell-wise SWAP/MODFLOW flux residuals must satisfy the qualified tolerance.

## Publication

After coupled convergence the prepared MODFLOW solve is finalized. Both SWAP candidate preflights and both prepared-ledger preflights must pass, followed by the MODFLOW timestep readiness check. Only then is the publication point crossed: MODFLOW finalize_time_step exactly once, both SWAP kernel commits in deterministic interface order, then both prepared ledger commits.

Each ledger records the whole-window exchange of its own 1:1 interface and must close against that interface's accepted SWAP exchange.

## Evidence boundary

F-GC46 is multi-cell software/runtime coverage. It does not qualify N:1 within a cell, heterogeneous aggregation science, larger prescribed-head changes, active drainage, root uptake, macropores, snow, soil temperature, Ribasim, irrigation or runtime finite-difference tangent fallback.

Predictor/corrector ownership remains inside the internal SWAP5-MODFLOW coupling service below iMOD Coupler.
