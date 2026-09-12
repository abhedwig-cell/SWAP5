# EB-I01 Energy Conservation Ledger Contract

## Scope

EB-I01 adds generic energy-accounting infrastructure to the SWAP5 kernel/runtime transaction model. It does not add or change a physical heat solver and it does not replace any existing mass-accounting authority.

The production delta is intentionally additive:

- `src/kernel/mod_energy_conservation_types.f90`
- `src/runtime/mod_energy_conservation_ledger.f90`

Existing mass, groundwater, state-transition and solver implementations remain unchanged.

## Units and reference area

All stored-energy values named `*_energy_j_m2`, transfer values named `*_j_m2`, and balance terms in `energy_balance_t` are interval-integrated energy in J/m2.

The reference area is the owning logical SWAP column or tile area. EB-I01 does not know the fraction of a MODFLOW cell occupied by a tile and does not aggregate tile energy or fluxes to a groundwater-cell area. Surface-fraction weighting, cell-area conversion and system composition belong to the runtime/coupler outside the SWAP kernel.

## Components and transfers

A positive component id denotes a registered energy-accounting component inside the logical model composition. Component id `0` (`ENERGY_EXTERNAL_COMPONENT`) denotes the environment outside that registered system.

Every positive transfer endpoint must occur in the registered trial storage snapshot. An unknown positive endpoint is invalid and may not be silently reclassified as external. The runtime rejects it when the transfer is recorded, and the generic control-volume projector independently rejects a transfer whose positive endpoint is absent from its storage snapshots.

For a nested control volume, a registered positive component that is not selected is outside that particular control volume even though it remains part of the registered logical system. This distinction is what allows one directed transfer to be internal in a larger control volume and a boundary transfer in a nested one.

A transfer is represented by a non-negative magnitude plus explicit direction:

`source_component -> target_component : amount_j_m2`

Negative transfer magnitudes are invalid. Reversing a physical transfer is represented by reversing source and target.

For a selected control volume:

- outside -> inside contributes to `boundary_input_j_m2`;
- inside -> outside contributes to `boundary_output_j_m2`;
- inside -> inside contributes to `internal_transfer_j_m2` only;
- outside -> outside is irrelevant to that control volume.

`internal_transfer_j_m2` is a gross diagnostic. It is deliberately excluded from the net conservation residual.

The conservation identity is:

`residual = (final_storage - initial_storage) - boundary_input + boundary_output`

A closed balance therefore has `residual_j_m2 = 0` within the numerical tolerance selected by the caller or qualification test. EB-I01 itself does not silently relax conservation.

## Nested control volumes

The same transfer can be internal for an outer control volume and a boundary transfer for a nested control volume. EB-I01 therefore records directed trial transfers rather than only pre-aggregated in/out totals.

Nested projections are available while the trial event stream exists. `prepare_trial` freezes the total-column result needed for commit publication and discards the detailed event stream. The committed EB-I01 record is intentionally compact and does not preserve a permanent transfer graph for each column.

## Transaction contract

The energy ledger does not decide whether a physical state is accepted.

1. `begin_trial` creates worker-local accounting for one physical origin lineage, revision and generic interval `[t0,t1]`.
2. `record_transfer` and `set_end_storage` populate only that trial.
3. `prepare_trial` computes and validates the energy balance before the physical commit. It freezes a compact prepared handle and discards trial scratch.
4. A successful physical kernel commit creates the existing `fmr_accepted_commit_receipt_t` authority.
5. `commit_prepared` may publish an `energy_commit_record_t` only when lineage, origin revision and interval match that accepted receipt.
6. A rejected or rolled-back physical trial uses `discard_trial` or `abort_prepared` and publishes no energy commit record.
7. Recalculation from the same committed physical origin creates a new trial and can be committed normally after a new accepted receipt.

The ledger has no independent commit bit, transaction engine or mutable post-commit publication counter. The existing physical transaction remains authoritative.

## Lifetime and memory ownership

`energy_trial_ledger_t` is intended as worker/job scratch, not persistent per-column physical state. Its transfer array exists only while energy accounting is active for a trial. A prepared trial retains only compact provenance plus the aggregate balance required for controlled publication.

Instantiation policy is therefore a runtime responsibility: MultiSWAP workers may reuse ledger objects across columns/jobs, while columns for which energy accounting is inactive need not carry this scratch allocation.

## Relationship to mass accounting

EB-I01 is orthogonal to existing mass accounting. It does not import the groundwater-specific mass ledger and does not change canonical water-balance equations, groundwater exchange publication, candidate acceptance or committed mass state.

Mass conservation remains a separate hard invariant. The EB-I01 gate recompiles and executes the unchanged FMR18 accepted-commit/mass transaction test without linking the new energy modules.

## Explicit non-claims

EB-I01 does not yet prove that existing SWAP heat, canopy, surface, snow or soil-temperature processes emit complete energy transfers into this ledger. That physical wiring belongs to subsequent energy-balance workunits.

EB-I01 also does not yet qualify:

- large-batch MultiSWAP throughput or memory scaling;
- thread-race behavior under concurrent workers;
- a bounded-cost policy for unusually large transfer graphs;
- runtime-wide reporting/serialization of energy diagnostics;
- MODFLOW-cell or tile-fraction aggregation;
- a physical heat solver or its scientific accuracy.

Those are separate qualifications and must not be inferred from the EB-I01 accounting gate.
