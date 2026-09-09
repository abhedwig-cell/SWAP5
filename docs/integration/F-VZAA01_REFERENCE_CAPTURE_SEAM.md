# F-VZAA01 - FullRichards trajectory-capture seam for D0 donor falsification

## Purpose

F-VZAA01 D0 needs time-resolved reference moisture and layer-midpoint fluxes to test whether the VZAA history-aware analytical flux relation contains an independently useful donor signal.

This note identifies the minimum evidence seam in the existing LayeredMFP/FullRichards experimental harness. It does not authorize VZAA integration and does not change production kernel contracts.

## Live source examined

LayeredMFP branch observed for this seam analysis:

`work/f-lmfp09-hydraulic-envelope-geometry`

Relevant experimental/reference files:

- `experiments/lmfp/run_lmfp04_ab_gate.sh`
- `experiments/lmfp/test_lmfp04_fullrichards_reference.f90`
- `experiments/lmfp/run_lmfp04_ab.py`
- `src/solver/mod_soil_water_solver_contract.f90`
- `src/solver/mod_reference_richards_workspace.f90`
- `src/adapter/mod_reference_richards_legacy_binding.f90`
- `src/legacy/b1_10_port/headcalc.f90`

## 1. The existing reference driver is already step-resolved

`test_lmfp04_fullrichards_reference.f90` does not execute one opaque whole-run call.

For each case and refinement it:

1. constructs an explicit `soil_water_solve_request_t`;
2. calls `solver%solve(request, ws, result)` once per numerical time step;
3. rejects non-converged or fallback steps;
4. obtains `result%candidate_state%pressure_head` and `result%candidate_state%water_content`;
5. obtains realized `result%top_flux` and `result%bottom_flux`;
6. computes the unrounded accepted-step storage change and mass residual;
7. only then copies the candidate state into `request%base_state` for the next step.

Therefore time-resolved state capture requires no new time engine, no legacy file output, no calendar semantics and no production control-flow change.

The minimum experimental change is simply to record values already available before the driver performs its manual commit to `request%base_state`.

## 2. The public soil-water result contract intentionally does not expose all internal face fluxes

`soil_water_solve_result_t` currently contains:

- candidate physical state;
- realized top flux;
- realized bottom flux;
- unrounded mass-balance residual;
- diagnostics;
- bottom-interface sensitivity.

It does not contain an `N+1` internal face-flux vector.

This is not a defect for D0. Internal solver flux scratch should not be promoted to permanent column state merely to support one qualification experiment.

The ReferenceRichards workspace does contain worker-owned arrays such as `vertical_flux(:)` and `head_gradient(:)`, but D0 should not make those HeadCalc internals part of a generic soil-water API unless a later architecture workunit independently justifies such an observer/output contract.

## 3. D0-A can reconstruct accepted ledger face fluxes without HeadCalc internals

The existing F-LMFP04 D0-A candidate family sets source and sink providers to zero.

Using downward-positive notation for the D0 evidence, define for accepted step `n` and layer `i`:

`Delta S_i = dz_i * (theta_i^{n+1} - theta_i^n)`.

The existing FullRichards driver uses upward-positive solver fluxes and tests

`Delta S_column + dt * (q_top_up - q_bottom_up) = residual`.

Convert the realized top boundary transfer to downward-positive:

`Q_0 = -result%top_flux`.

With zero distributed source/sink, recursively reconstruct the ledger-consistent internal/downstream face transfer:

`Q_i = Q_{i-1} - Delta S_i / dt`.

After `N` layers,

`Q_N = Q_0 - sum_i Delta S_i/dt`.

If the accepted column residual were exactly zero this would equal `-result%bottom_flux` exactly. With a finite FullRichards balance residual, the mismatch is the corresponding residual expressed as flux.

For VZAA Eq. (7), define the reference layer-midpoint ledger flux:

`Q_ref_mid,i = 0.5 * (Q_{i-1} + Q_i)`.

This is the correct primary D0 quantity if the scientific question is whether the VZAA layer-centred flux estimate predicts the water transfer actually implied by the accepted conservative reference trajectory.

## 4. Why this is preferable to reading raw HeadCalc flux scratch

For the first donor-separability experiment, continuity reconstruction has several advantages:

- it uses only public accepted state plus realized external transfers;
- it is independent of HeadCalc array naming and legacy internal layout;
- it exactly follows the accepted water ledger;
- it remains compatible with the architectural rule that other modules must not know HeadCalc internals;
- it makes any residual mismatch at the bottom visible instead of silently hiding it;
- it avoids widening production API surface for experimental evidence.

This does not mean that the ledger flux and the constitutive Darcy flux are mathematically identical when the nonlinear FullRichards solve retains a finite local residual.

## 5. Optional cross-check: accepted ledger flux versus final Darcy flux

A later experimental cross-check may inspect or reconstruct the final FullRichards Darcy face flux, but it must remain explicitly diagnostic.

Useful comparison:

`epsilon_face,i = Q_darcy_final,i - Q_ledger,i`.

If `epsilon_face` is negligible relative to the VZAA versus LayeredMFP signal, the ledger flux is sufficient for D0.

If it is not negligible, the D0 experiment must report both quantities rather than choosing whichever makes the donor appear better.

No generic `face_flux(:)` result field should be added solely for F-VZAA01 before this need is demonstrated.

## 6. Minimum FullRichards trajectory record

For each accepted step, record:

- case id and refinement;
- step index;
- accepted step duration;
- cumulative elapsed time from the case start;
- old layer water content;
- accepted new layer water content;
- accepted new layer pressure head;
- realized top flux in native solver sign and normalized downward-positive sign;
- realized bottom flux in both signs;
- `Delta S_i` for every layer;
- reconstructed downward-positive `Q_0 ... Q_N` ledger faces;
- reconstructed `Q_ref_mid,i`;
- column mass residual;
- nonlinear iteration and fallback diagnostics.

For the current D0-A cases the reference record can be generated entirely in the experimental driver before committing the candidate state.

## 7. Minimum LayeredMFP trajectory record

The existing Python candidate already advances one accepted trial at a time through `advance_trial(...)` and receives candidate storage plus face fluxes.

A future cross-track recorder should retain, for each accepted step:

- old and new storage/moisture;
- face flux vector from the accepted candidate trial;
- midpoint LayeredMFP fluxes;
- mass residual;
- face-iteration count and retry information;
- elapsed time.

Raw trajectory history is evidence output for D0. It is not a proposal for persistent MultiSWAP column state.

## 8. VZAA history must use only deployable candidate history

D0 must compute the VZAA half-order history operator from the LayeredMFP/candidate committed moisture trajectory, not from the FullRichards reference trajectory.

Otherwise the donor would receive future production-unavailable reference information and the experiment would answer only whether VZAA can interpolate a FullRichards trajectory after the fact.

The FullRichards trajectory is used only to score the prediction.

## 9. Source/sink generalization is deliberately deferred

For nonzero distributed source/sink, face reconstruction becomes

`Q_i = Q_{i-1} + dt-normalized source/sink contribution - Delta S_i/dt`,

with exact sign and ownership determined by the generic soil-water transfer contract.

D0-A does not need this generalization because its source and sink providers are zero. Adding it now would broaden the experiment without evidence that the VZAA donor survives the simplest falsification gate.

If D0-A survives, a later workunit must source-bind the generic per-layer source/sink ledger before extending the method to roots, drainage, irrigation or macropore exchange.

## 10. No production API change is currently justified

Current seam decision:

`EXPERIMENT_ONLY_STEP_RECORDER_SUFFICIENT_FOR_D0_A__NO_PRODUCTION_SOLVER_CONTRACT_CHANGE_REQUIRED`

This is important architecturally. The existing solver contract already supports the transactional sequence needed for the experiment, while ReferenceRichards scratch remains worker-owned.

## 11. Remaining execution blocker

The logical capture seam is now identified, but D0 is not yet executable on the current F-VZAA01 branch because the LayeredMFP experimental harness lives on the separate active LayeredMFP workstream branch.

The next safe action is to define a small cross-track evidence workunit based on the authoritative LayeredMFP experimental head, with scope limited to:

1. add trajectory recording to the experimental FullRichards and LayeredMFP harnesses;
2. independently reconstruct the source-bound VZAA diagnostic equations;
3. run D0-A without changing accepted solver physics or production code;
4. persist raw and summarized evidence;
5. stop immediately if the donor signal is falsified.

Do not copy the complete LayeredMFP harness onto F-VZAA01 and do not merge exploratory VZAA changes into the LayeredMFP owner branch before this cross-track evidence scope is explicitly reserved.
