# F-SI03 - Source-bound reference Richards adapter

## Status

F-SI03 qualifies a narrow migration adapter contract between the F-SI02 soil-water solver interface and the existing B1.10 `HeadCalc` symbol. It does not qualify the full B1.10 Richards solver as reentrant, transaction-clean or production-admitted through this adapter.

Qualified scope: `QUALIFIED_SOURCE_BOUND_ADAPTER_CONTRACT_ONLY`.

## Exact basis

- F-SI02 qualified head: `da1d5da0d909c5ce55efa17507b805bffd6b82f9`
- F-CI18 canonical closeout: `7f906fcc53a4133b0e410eac7cf79fbb4eb672ab`
- qualified production-source head: `da5026d8b87ad2f3c7912360891839a120ecccb6`
- corrected legacy oracle: B1.10
- current F-KT head observed during closeout: `b5e7ec8564b5f6e2b53844388fbb870fa3264d07` (F-KT03)
- F-KT to F-SI boundary blob remains `ee1a153c30bbae9416ce08414e8b56049d3d14db`

F-KT03 confirms that conversion from the cloned generic physical snapshot to `soil_water_physical_state_t` is owned by an F-SI adapter or model implementation. F-SI does not own candidate provenance, commit or rollback.

## Placement

The transition implementation is `src/adapter/mod_reference_richards_legacy_binding.f90`, not `src/solver`.

This is deliberate. The F-SI02 common solver layer remains free of `variables`, `MOD_grid`, `MOD_swap_base`, file I/O and hidden `SAVE` state. Legacy-global translation is therefore visible as migration debt rather than becoming part of the common soil-water API.

## Bound behavior

The adapter:

1. builds an F-SI request from the current B1.10 state and numerical settings;
2. validates the request against the current legacy geometry and numerical policy;
3. overlays the request base state onto the legacy HeadCalc state required for the call;
4. calls the source-bound symbol `headcalc(worker)` through an explicit worker context;
5. maps candidate `h`, `theta`, ponding depth, groundwater level, top flux, bottom flux and solver diagnostics into `soil_water_solve_result_t`;
6. maps legacy timestep-reduction advice to `SW_SOLVE_RETRY_ADVISED` without performing F-KT commit or rollback;
7. restores the legacy physical/checkpoint fields explicitly covered by this slice before returning.

The adapter deliberately reports the unrounded mass-balance residual as NaN. A finite residual would incorrectly imply that F-SI03 had already bound and qualified the complete physical accounting required by invariant 13.

## Fail-closed subset

F-SI03 admits only the migration subset for which no unresolved optional-process state is silently moved into worker scratch:

- `swmacro == 0`;
- `swkimpl == 0`;
- `fldtmin == .false.`;
- lower boundary `swbotb == 7` or `swbotb == -2`;
- top boundary remains explicitly identified as legacy-managed context through `FSI_LEGACY_TOP_CONTEXT`.

Macropores, implicit conductivity, minimum-timestep fallback behavior and other lower-boundary modes are rejected before `HeadCalc` is called.

## Qualification

Workflow run `34121073167`, job `101738972331`, tested head `79e3e9052a4f68306b8c826b063497247fd339d6` passed under GNU Fortran 13.3 with strict warnings-as-errors and runtime checking.

The executable binding harness verifies at O0 and O2:

- request base state is the state presented to the bound HeadCalc symbol;
- candidate state and boundary fluxes are returned separately from the request;
- covered legacy state is restored after the trial call;
- retry advice is returned as solver status, not executed as a transaction action;
- A/B/A request order reproduces A at the adapter-contract level;
- poisoning the F-SI02 Richards workspace does not contaminate the deterministic adapter harness;
- unsupported physics and numerical routes fail closed before the bound symbol is called;
- wrong workspace type fails closed;
- the F-SI02 common contract/workspace executable tests still pass at O0/O2 and 1/2/4/8 OpenMP threads.

The harness uses a deterministic test `HeadCalc` implementation with the same external signature. This proves the binding and transaction-facing semantics, not B1.10 numerical identity.

## Source protection

F-SI03 leaves these qualified sources byte-identical to F-SI02:

- `src/legacy/b1_10_port/headcalc.f90`
- `src/legacy/b1_10_port/soilwater.f90`
- `src/runtime/mod_a23bu_worker_execution_context.f90`
- `src/transaction/mod_transaction_reference.f90`
- `src/solver/mod_soil_water_solver_contract.f90`
- `src/solver/mod_reference_richards_workspace.f90`

The production `soilwater.f90` route therefore still calls `HeadCalc` directly. F-SI03 does not switch production routing.

## Holds

F-SI03 does not prove any of the following:

- full B1.10 `HeadCalc` numerical identity through the adapter;
- full legacy side-effect rollback outside the explicitly covered state fields;
- full Richards solver reentrancy or concurrent execution;
- actual Newton/Jacobian storage in `reference_richards_workspace_t`;
- macropore state isolation;
- implicit-K isolation;
- explicit top-boundary/provider extraction;
- full lower-boundary contract coverage;
- unrounded water-balance identity;
- interface tangent `dh_bottom_dq_bottom`;
- production reference admission.

In particular, the real `HeadCalc` still contains local Newton arrays and accesses broader legacy process state. That prevents a defensible full-reentrancy claim at this point.

## Invariant assessment

F-SI03 preserves the single-kernel boundary, keeps the common solver layer independent of I/O and legacy globals, keeps physical candidate state separate from worker scratch, leaves transaction authority with F-KT, keeps numerical policy explicit and unchanged, and fails closed for unsupported optional physics. Mass conservation remains a hard requirement, but its adapter-level accounting evidence is intentionally held rather than fabricated.

## Next work unit

F-SI04 should bind the actual reference Richards scratch ownership more deeply: remove or redirect the remaining HeadCalc-local Newton/Jacobian work arrays onto an F-SI-owned workspace on the source-bound path without changing equations or numerical policy. Real HeadCalc replay and poisoning evidence should then be added before moving on to broader provider extraction.
