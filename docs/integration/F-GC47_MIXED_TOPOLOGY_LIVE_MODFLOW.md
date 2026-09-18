# F-GC47 — Mixed-topology real SWAP + live MODFLOW6 application

## Scope

F-GC47 composes two already-admitted runtime topologies inside one live MODFLOW6 6.8.0 timestep. Groundwater cell 7001 receives two independently transactional real FMR/SWAP columns through the admitted F-GC40 N:1 response. Groundwater cell 7002 receives one independent real FMR/SWAP column through the same single-tile-equivalent response path.

This is software/runtime composition qualification. It does not claim that heterogeneous unsaturated-zone columns are scientifically replaceable by an equivalent column.

## Topology

Three unique SWAP lineages and three independent ledgers participate. Cell 7001 has area fractions 0.35 and 0.65; cell 7002 has one tile with fraction 1.0. All three use the same physical parameterization and the same short near-equilibrium numerical envelope already admitted by F-GC44/F-GC45.

F-GC40 reduces the two cell-7001 predictor responses to one affine cell response and reduces the cell-7002 predictor through its single-tile equivalence. F-GC34 publishes those two cell responses to API package slots 1 and 2, mapped to distinct MODFLOW nodes.

## Corrector routing

Within every coupling iteration, the two SWAP tiles contributing to cell 7001 both receive the current head of cell 7001. The third SWAP column receives only the current head of cell 7002. Each trial starts from that participant's immutable accepted checkpoint. Nonfinal candidates for all three participants are discarded together before the next coupling iteration.

Cell-7001 convergence uses the area-weighted corrector flux 0.35*q1 + 0.65*q2. Cell-7002 convergence uses q3 directly. Acceptance requires MODFLOW nonlinear convergence plus both cell-level interface residuals within tolerance.

## Publication

After coupled convergence, the prepared solve is finalized. All three SWAP publication preflights and all three prepared-ledger preflights must pass, followed by the shared MODFLOW timestep readiness check. The irreversible publication sequence is MODFLOW finalize_time_step once, then all three SWAP kernel commits in canonical cell/tile order, then all three ledger commits.

The sum of the first two committed ledgers must close against the accepted whole-window exchange for cell 7001; the third ledger must close against cell 7002.

## Evidence boundary

F-GC47 has production source delta NONE. It does not expand the prescribed-head envelope, activate drainage/root uptake/macropores/snow/soil temperature, add Ribasim or irrigation, or admit runtime finite-difference tangents.

Predictor/corrector ownership remains inside the internal SWAP5-MODFLOW coupling service below iMOD Coupler.
