# SWAP5-MODFLOW6 current implementation semantic trace

Date: 2026-09-20

Authority preimage: `integration/f-ci-canonical@919bbf76370c2136932daa04ad88135e7d1615a8`.

This trace describes what the current production path actually does. It deliberately separates application meaning from numerical realization.

## 1. Accepted origins

The production path keeps two different state concepts.

- SWAP/FMR owns its committed column state and one immutable checkpoint/origin for the coupling window.
- MODFLOW6 owns the groundwater model state. During one prepared solve, `XOLD` remains the accepted previous-time groundwater state and `X` is the evolving nonlinear iterate.
- The interface mass ledgers are separate accepted-publication objects. Trial calculations are not authoritative mass.

This separation is correctly represented by F-GC38/F-GC39/F-GC41 and the F-GC49 application service.

## 2. Predictor construction

The MODFLOW-oriented SWAP predictor is not a mode-5 calculation.

The admitted F-GC30 route starts from the accepted SWAP origin and runs a prescribed-`qbot` trial. From that trial it constructs:

- the terminal lower-face hydraulic head `H_bot,end`;
- the derivative `dH_bot/dq_bot`;
- the dimensionless finite-window response coefficient
  `u = DeltaT / (dH_bot/dq_bot)`;
- the historical predictor quantity
  `q_u = u (H_end-H_start)/DeltaT - q_bot`.

F-GC40 aggregates tile responses to a MODFLOW cell. F-GC33 then forms an affine MODFLOW API-package response

`q_u(H) = q_ref + (u/DeltaT) (H-H_ref)`

and converts it to `HCOF/RHS`.

Therefore `q_u` and `u` are predictor/linear-response quantities. They are not, by themselves, accepted interface mass.

## 3. MODFLOW prepared-solve iteration

`Modflow6PreparedSolveSession` opens one prepared solve for the window. The production application service repeatedly:

1. publishes the current affine F-GC33 terms;
2. advances MODFLOW by one external nonlinear iteration;
3. reads the current MODFLOW node/cell hydraulic head from `X`;
4. evaluates the API-package flux at that same head.

The head read here is a MODFLOW groundwater iterate. It is not an accepted groundwater state until the whole coupled window is accepted.

## 4. SWAP corrector trial

The current F-GC49D application context passes each MODFLOW trial cell head directly to the mapped SWAP participant.

`mod_fmr_groundwater_swap_participant` delegates the head to the configured groundwater forcing materializer. The concrete FMR materializer:

- requires `bottom_mode == 5`;
- interprets the supplied number as an interface hydraulic head;
- uses the explicit lower-boundary datum to calculate
  `psi_bottom = 100 (H_interface-z_bottom)`;
- materializes that value as the SWAP lower-face pressure-head forcing;
- replays the whole SWAP window from the immutable accepted checkpoint.

The corrector then returns the whole-window SWAP bottom exchange as a mean outward-from-SWAP interface rate.

This is a mathematically valid way to realize a head-driven SWAP trial. It does **not** establish that the coupled application is scientifically a standalone legacy SWBOTB=5 application.

## 5. Coupling residual and re-anchoring

The application service compares:

- the SWAP corrector rate at the current MODFLOW head; and
- the MODFLOW API-package rate obtained from the current affine response.

The production residual is their difference. Coupled convergence requires MODFLOW nonlinear convergence and the per-cell flux residual to meet the governed tolerance.

If the window is not coupled-converged:

- the SWAP candidate is discarded;
- MODFLOW `X` remains the current iterate inside the same prepared solve;
- F-GC33 re-anchors the affine term at the current head so that its reference flux equals the latest realized SWAP corrector flux;
- the existing response slope is retained for the next iteration.

This is important for interpretation. The initial `q_u` is a predictor response. After re-anchoring, the affine MODFLOW term is locally tied to the realized SWAP corrector exchange. At convergence the MODFLOW package flow and SWAP bottom exchange agree to the coupling criterion.

## 6. Accepted publication

After coupled convergence:

1. the MODFLOW prepared solve is finalized;
2. SWAP and ledger preflights run;
3. the MODFLOW timestep is finalized at the irreversible publication point;
4. SWAP candidate states are committed;
5. interface ledgers are committed.

The accepted ledger records the accepted SWAP whole-window bottom transfer. In the current iterative algorithm the MODFLOW API-package rate is required to agree with that transfer at convergence.

Therefore the accepted mass contract is not `predictor q_u == accepted recharge`. The stronger statement supported by the current implementation is:

`accepted MODFLOW API transfer ~= accepted SWAP whole-window bottom transfer`

within the explicit coupling residual criterion.

## 7. Head semantics that the code currently assumes

The code uses an identity transfer operator:

`H_trial,SWAP-bottom = H_trial,MODFLOW-node`.

That identity is a coupling assumption, not a consequence of either model.

It is consistent with the 2024 SWAP-MODFLOW finalization concept in which the MODFLOW head is imposed at the bottom of SWAP, provided that:

- the intended coupling-plane datum is explicit;
- the MODFLOW node head is the head selected to represent that coupling condition;
- the value is not reinterpreted as the diagnostic SWAP phreatic level.

The current topology contract maps tile to groundwater cell but does not encode a separate vertical transfer geometry, resistance, or head-transfer operator. Applications that require such a transfer cannot be inferred from the present identity mapping.

## 8. Application-profile leak

The abstract `groundwater_swap_forcing_materializer_t` already says the orchestrator owns coupling semantics and the materializer only realizes a restricted forcing representation.

The concrete FMR implementation nevertheless uses `bottom_mode == 5` as its admission key, and the production bootstrap repeats that requirement as the definition of a groundwater profile.

That is the exact location where an internal trial representation has leaked into application-level scientific authority.

## 9. Drainage and root uptake

The production bootstrap additionally rejects `drainage_response_active` and `root_extraction_active` for the groundwater profile.

Those rejections are current implementation/admission limits. They are not consequences of legacy SWBOTB=5 physics.

Root uptake is a SWAP column sink and should remain a SWAP process in a coupled application. It can affect the predictor/corrector response and therefore requires numerical derivative/response coverage when the chosen coupling method uses such information.

Drainage requires an explicit coupling-topology owner. A physical drainage path may be represented by SWAP or by the groundwater model/surface-water coupling, but the same path must not be booked by both.

## 10. Storage semantics still missing from the production contract

The predictor coefficient `u` is explicitly derived from the SWAP finite-window head response and enters the MODFLOW API-package slope as `u/DeltaT`. It is therefore storage-like coupling response information.

The repository correctly does **not** reinterpret `accepted_storage_change` as `u`.

However, the production topology/application contract does not state which physical storage volume represented by `u` is excluded from, supplements, or overlaps MODFLOW STO storage. The live qualification fixtures use both a nonzero MODFLOW STO package and the SWAP-derived affine response, but those fixtures were designed to qualify numerical composition, not to establish a production hydrogeological storage partition.

Until a storage-domain partition is explicit, absence of double storage counting is not established for a realistic coupled application.

## 11. Current semantic verdict

The current numerical execution path contains a coherent partitioned iteration and accepted-state publication mechanism.

The semantic defects are at its boundaries:

- a mode-5 implementation representation is promoted to application admission authority;
- the MODFLOW-node to SWAP-bottom identity map is implicit rather than an explicit application transfer assumption;
- drainage ownership is not part of the coupling topology;
- the physical storage partition behind the SWAP-derived `u` term versus MODFLOW STO is not explicit.

No evidence found in this audit justifies calling the prepared-solve iteration itself numerically invalid.
