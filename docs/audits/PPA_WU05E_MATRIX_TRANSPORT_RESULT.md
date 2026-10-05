# PPA WU05 E selected matrix transport result

The selected matrix E1/E2/E3/E4 dissolved-salt/root-stress successor is qualified and READY_FOR_REGIE. Canonical admission is owned by central SWAP5 regie under the [project control model](../development/SWAP5_PROJECT_CONTROL.md).

The exact replay tested commit `571a76c473949dccd5e690261fea0d8a0a1ea15c`, tree `95db85d2c0a45775f88d197696e11704a8cd2948`, [run 37320018572](https://github.com/abhedwig-cell/SWAP5/actions/runs/37320018572). Immutable artifact identity and full source manifests/results are recorded in `integration/audits/PPA_WU05E_MATRIX_TRANSPORT_QUALIFICATION.json`; the requested central action is in `integration/audits/PPA_WU05E_REGIE_HANDOFF.json`.

## Qualified behavior

- Selected matrix dissolved mobile salt: source molecular/mechanical dispersion, conservative upwind advection and donor-bounded internal solute stepping
- One Richards/root-water sink with independent salt ledger and integrated per-node root and signed per-level drainage receipts
- Explicit hydraulic geometry/saturation binding, zero-solute qssdi, evaporative salt retention and separately declared liquid top export
- Actual Feddes/Bartholomeus/Maas-Hoffman/Jarvis stress/application chain, reject/retry/discard/commit and Restart v4 fresh-process continuation
- O0/O2 analytical/refinement process oracles and D2/D3/Richards/macropore preservation gates

The source physical face coefficient and both interpolation weights are bound explicitly to the hydraulic owner. Existing conservative upwind advection is combined with dispersion using the same start concentration and positive donor-bounded steps. Root salt receipts integrate internal concentrations while retaining the single accepted root-water sink. Evaporation retains dissolved mass; an explicit liquid-export forcing carries donor concentration. Failed late substeps expose neither candidate nor partial receipts.

Independent process checks include two-node analytical relaxation, Gaussian spatial refinement, drying TSCF=10 temporal refinement, atomic failure and a manufactured 365-day ledger schedule. Actual caller/application checks cover all seven mixed stress cases and three top boundary cases at O0/O2, changed forcing in separate restart processes, reject/retry/discard/commit and preservation of D2, D3 and Richards/macropore routes.

## Qualification limits

- Full B1.11 numerical or bitwise equivalence: legacy centered advection and artificial dispersion correction are not ported
- Sorption, decomposition, surface concentration pools, aquifer breakthrough and coupled groundwater salt state
- Osmotic-head mode, frost and new macropore dispersion physics
- Seasonal real Richards/FMR or field validation: the 365-day schedule is a manufactured process oracle

## Central handoff

Central regie must reconcile the candidate against the live canonical head, including shared application/runtime/numerical interfaces, then ADMIT, RETURN or SUPERSEDE. Read-only merge preview against canonical `c7f9a7b85ef937347893f2fbd1653b4c00a724af` found conflicts in `src/runtime/mod_fmr_restart_state_contract.f90` and `src/runtime/mod_fmr_serialized_reference_backend.f90` after INT13 Rutter admission. MIGMAC07/08/09 also changed macropore preservation dependencies. This isolated candidate replay does not qualify a merged successor. The handoff records exact preview output and requires central reconciliation to preserve both optional-state layouts and replay both owners plus changed macropore dependencies.

This specialized stream has not changed the central registry, frozen Status A authority or canonical admission state. Historical qualification records remain immutable and are superseded for this dependency surface by the exact replay above.
