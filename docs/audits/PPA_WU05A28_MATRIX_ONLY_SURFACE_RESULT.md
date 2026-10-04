# A28 matrix-only surface continuation result

Date: 2026-10-04. Status: COMPONENT_TESTED / LIVE_REPAIR_FALSIFIED / COUPLED_RFM_BLOCKED.

Goal remains full24-window exact-RFM coupling with explicit water ownership before A28. Baseline348e4921; current canonical checked at9605fbb1. Canonical still has A15's unponded restriction. Branch/canonical backend and preparer deltas are not silently reconciled or admitted.

A separately named `mod_rfm_matrix_only_surface_composition` implements the exact zero-preferential degeneration. Existing A15 production code is unchanged. It requires a valid activation receipt with exactly zero rate and fraction, mass-carrying resolved dynamic-top preflight, finite nonnegative surface terms and matching matrix/external supply. Positive preferential rates even1e-30 return REFERENCE_REQUIRED. The existing dynamic top remains the pond/runoff owner. O0/O2 bounds-checked service tests and original A15 tests pass; the generated live binding remains optional and unadmitted. Adding this unused production-location component is distinct from changing default production execution.

Fresh full build and initial rain1 FD regression pass. Frozen exact24 with the matrix-only fallback accepts16 windows, then predictor17 fails. The published16 rows are bitwise equal to the preceding anchored/accepted-basepoint control. The failing transaction now executes18 nonlinear/Jacobian/linear iterations, accepts no substep and reports13 attempts/12 retries,13 solver-class rejections and0 mass rejections. Aggregate solver classification is not a nonlinear-convergence diagnosis.

A separately registered stage-observation replay through17 reproduces the same accepted rows. At dt9.765625e-8, the origin is unponded, activation has valid zero preferential supply and the surface/wall/candidate stages all pass. The first half at4.8828125e-8 likewise passes. Its candidate ponding is7.3304328e-8 cm. At the second half's origin, A11 receives this positive ponding and returns RFM_ACTIVATION_SURFACE_BOUNDARY_REQUIRED by its explicit source guard. The matrix-only service rejects that unavailable receipt. The displayed zero rate/fraction are default fields, not evidence of zero physical preferential inflow. Smaller trials repeat the same transition. A synthetic regression proves that a ponded A11 result cannot masquerade as a valid matrix-only receipt. No numerical threshold is loosened to circumvent this capability boundary.

The independently derived dynamic-top oracle retains BOFEK00 provider derivative/candidate-independence gates and verifies:

```text
rain*dt + old_pond = matrix_infiltration*dt + candidate_pond + runoff
```

Ponded and linear-runoff cases close within3.687e-18 cm. Their pond changes are .003015483 and .008514141 cm; the latter has runoff .001724553 cm. Thus external atmospheric receipts cannot generally be represented by actual matrix infiltration when whole-column storage includes ponding. The current RFM backend's `account_external_fluxes` receives solver_top_flux, so a general ponded RFM binding must additionally materialize explicit surface external receipts. This is a contract requirement and oracle finding, not a claim that the failed live transaction reached or failed a mass gate (it did not).

Independent accepted-window inventory again matches the direct ledger within5.205e-16 cm, local residual2.498e-16. Deep-receipt receiver, nonzero accepted RFM storage and the original activity gates remain unresolved. No A28/performance claim follows.

## Concrete next capability and acceptance boundary

Resume under one joint surface/RFM composition owner, as already required by A14. Its same-origin candidate must own atmospheric input, evaporation, surface storage change, runoff, matrix entry and preferential entry together; then produce exactly-once external receipts for the transaction. It must supply a valid ponded activation/entry receipt, rather than feed default zero fields from A11 into a fallback or repartition matrix `actual_top_flux`. A15, the Reference dynamic-top law and existing F-GC accepted-state/commit/discard contracts remain preservation controls. Existing SCV work is a dependency to reconcile, not an implicitly inherited capability or a second competing surface-store owner.

First acceptance gate for that new composition is the observed pond-startup whole/two-half transition, explicit surface mass closure and origin immutability/discard/replay; only then retry frozen exact24. The16-window prototype is neither full exact qualification nor an admitted repair. The exact-zero shortcut is convincingly insufficient, so additional tolerance/cap/shortcut runs are not justified. Decision remains COUPLED_RFM_BLOCKED.

Reproduce service tests with `python3 tests/fpe/run_fpe_a28_matrix_only_surface.py /tmp/a28-service`. Build using the preceding combined profile plus `A28_MATRIX_ONLY_SURFACE=1`; optional stage observation additionally requires `A28_RFM_PREPARER_DIAGNOSTICS=1 A28_MATRIX_ONLY_STAGE_DIAGNOSTICS=1`. Execute the original frozen exact workload with accepted_flux and16384 as registered; do not substitute its failed prefix for24-window qualification. Run `python3 tests/fpe/run_fpe_a28_surface_receipt_oracle.py /tmp/a28-build` against that complete build. Evidence bundle/manifest retain ordinary full logs, results, generated observer/oracle sources, hashes and preregistration chronology. No new Actions.
