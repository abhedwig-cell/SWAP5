# F-GC44 — Real SWAP + live MODFLOW6 end-to-end application

## Scope

F-GC44 closes the application-level evidence gap left by F-GC42 and F-GC43. It qualifies one restricted real FMR/SWAP soil column, one live MODFLOW6 6.8.0 cell, the admitted internal predictor/corrector lifecycle, and the F-GC41 publication boundary in one process.

The qualified first envelope is deliberately narrow and near-equilibrium, using the short F-GC30 production qualification window: one SWAP column mapped to one MODFLOW cell; serialized-reference Richards/FMR backend with the admitted Richards temporal-history/model-certificate route; prescribed groundwater-head lower boundary (bottom_mode=5) for correctors; drainage, root extraction, macropores, snow and soil temperature off; analytic accepted-trajectory tangent only; no runtime finite-difference fallback; no N:1 scaling.

## Production ownership

FMR keeps its kernel_executor_t private. F-GC44 does not expose that executor and does not create a second SWAP transaction owner. The backend gains only narrow candidate-publication methods delegating to the existing FMR checkpoint orchestrator: run_trial from the captured checkpoint, discard_trial_candidate, and commit_trial_candidate.

fmr_groundwater_swap_participant_t binds the F-GC43 participant contract to those backend-owned operations. It owns only coupling-local checkpoint/candidate provenance. The groundwater-head materializer maps hydraulic head to SWAP lower-face pressure head through the canonical interface_head_m_to_swap_bottom_pressure_head_cm contract.

## Real application path

The end-to-end qualification uses the real FMR/B1.10 Richards implementation to produce the accepted-trajectory predictor and every prescribed-head corrector. A qualification-only C ABI exposes that one real SWAP application instance to the Python live-MODFLOW harness; it is not a second production runtime or a new public SWAP API.

Sequence: real FMR accepted origin -> real analytic predictor/tangent -> F-GC40/F-GC33 linear MODFLOW response -> MODFLOW6 prepare_time_step + prepare_solve -> repeated affine publication / MODFLOW solve / real FMR corrector from the immutable accepted checkpoint / flux-residual check -> conjunctive convergence -> finalize_solve -> SWAP preflight -> prepared-ledger preflight -> MODFLOW timestep readiness -> publication point -> finalize_time_step -> kernel-owned SWAP commit -> prepared-ledger commit.

## Scientific and transaction invariants

The test requires one MODFLOW prepared solve per coupling window; fixed accepted MODFLOW XOLD; all SWAP correctors from one accepted kernel checkpoint; fixed analytic predictor slope; conjunctive MODFLOW + flux convergence; no participant publication before all preflights pass; exact publication order MODFLOW timestep then SWAP then ledger; one SWAP revision/time advance; one ledger exchange commit; and no second MODFLOW timestep finalization.

## Evidence boundary

This is an application qualification, not a scaling claim. It does not qualify heterogeneous N:1 aggregation, multiple coupled cells, Ribasim, irrigation, active drainage, root uptake, macropores, snow, or soil temperature.

The support C bridge exists only to exercise the already admitted real Fortran SWAP application and live xmipy/MODFLOW backend in one qualification process. Predictor/corrector ownership remains in the internal SWAP5-MODFLOW service below iMOD Coupler.


The qualification does not assert that arbitrary prescribed-head jumps are admissible within one SWAP coupling window. A deliberately larger head perturbation was observed to exhaust transaction retries in the real FMR route; expansion of that numerical envelope requires a separate qualification rather than relaxed tolerances here.
