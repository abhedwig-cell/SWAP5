# PB01 production outer-loop audit

Date: 2026-09-21
Status: CURRENT LIVE HARNESS ORCHESTRATION RECONCILED; PRODUCTIZATION GAP IDENTIFIED

## Reconstructed F-GC44 loop

The current real-SWAP + live-MODFLOW F-GC44 end-to-end harness performs the following outer iteration:

1. Publish the current HCOF/RHS term to the already prepared MODFLOW solve.
2. Execute one MODFLOW solve iteration.
3. Read the resulting coupling-cell head H_k.
4. Evaluate a fresh SWAP corrector trial from the immutable accepted origin at H_k.
5. Compute physical residual q_swap(H_k)-q_gw(H_k).
6. If both MODFLOW and flux residual converge, retain that SWAP trial for publication.
7. Otherwise discard the SWAP candidate, leaving committed SWAP state and the mass ledger unchanged.
8. Reanchor:
       RHS_{k+1}=HCOF*H_k-A*86400*q_swap(H_k)
   while HCOF is unchanged.
9. Repeat within the same prepared MODFLOW solve.

This is mathematically the reanchored surrogate analyzed by PB01.

## Relaxation/damping audit

The harness contains no explicit head relaxation, flux relaxation or HCOF damping between successive anchors.

The head update is whatever the prepared MODFLOW nonlinear solve returns after the new API HCOF/RHS term is published. Thus any effective damping in this path must come from MODFLOW's own nonlinear/linear solver behavior or from the surrounding aquifer system, not from an explicit SWAP-MODFLOW coupling relaxation parameter in this loop.

## Authority semantics

Every rejected SWAP corrector is computed from the immutable accepted origin and then discarded. Only the final converged trial is allowed through SWAP preflight, ledger preparation, MODFLOW timestep finalization, SWAP commit and ledger commit.

Therefore:
- the iterative affine boundary is numerical working state;
- rejected q_swap values are not accepted hydrological history;
- the final accepted interface amount comes from the final SWAP trial/ledger, not from integrating arbitrary intermediate affine surrogate values.

This supports a semantic distinction between numerical HCOF/RHS iteration terms and accepted physical exchange.

## Important limitation

The F-GC44 loop is currently a qualification/test harness, not evidence that a separate general production orchestrator executes the same algorithm everywhere. The backend provides the reanchor primitive, but the harness currently reimplements its algebra directly when updating RHS.

Therefore the current evidence supports:
- backend capability: CONFIRMED;
- live-harness algorithm: CONFIRMED;
- explicit coupling relaxation: ABSENT in harness;
- accepted-state isolation: CONFIRMED by harness assertions;
- universal production orchestration: NOT YET ESTABLISHED.

## PB01 implication

NH01 predicts rho=-4 for an isolated one-cell storage equation under this undamped positive-slope reanchoring. The existing F-GC44 aquifer has three cells, CHD end cells, aquifer conductance, storage, MODFLOW Newton iteration and a very short coupling window. Its observed convergence cannot be transferred to NH01 without a dedicated live one-cell experiment.

The next decisive experiment is therefore the preregistered PB01 live one-cell fixture, with:
- isolated one-cell groundwater storage;
- known exact root H=8.04 m;
- frozen current-orientation control;
- physical negative-tangent control;
- reanchored positive-slope outer iteration;
- explicit iteration trace and amplification measurement;
- no hidden coupling relaxation.
