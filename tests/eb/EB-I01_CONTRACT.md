# EB-I01 Energy Conservation Ledger Contract

## Scope

EB-I01 adds generic energy-conservation accounting infrastructure to SWAP5. It is an accounting contract and transactional publication seam, not a new heat solver and not a replacement for the existing mass-conservation authority.

The production source delta is deliberately limited to:

- `src/kernel/mod_energy_conservation_types.f90`
- `src/runtime/mod_energy_conservation_ledger.f90`

The kernel energy types know no files, parsers, paths, calendars, MODFLOW cell fractions or groundwater-specific mass ledger.

## Units and reference area

All energy storage and transfer quantities in EB-I01 are interval-integrated energy per unit reference area, in J/m2.

The reference area is the owning logical SWAP column or tile area. EB-I01 does not perform tile-fraction or MODFLOW-cell weighting. Those composition operations remain responsibilities of the runtime/coupler.

## Components and transfers

A positive component id denotes a registered energy-accounting component inside the logical model composition. Component id `0` (`ENERGY_EXTERNAL_COMPONENT`) denotes the environment outside that registered system.

Every positive transfer endpoint must occur in the registered trial storage snapshot. An unknown positive endpoint is invalid and may not be silently reclassified as external. The runtime rejects it when the transfer is recorded, and the generic control-volume projector independently rejects a transfer whose positive endpoint is absent from its storage snapshots.

For a nested control volume, a registered positive component that is not selected is outside that particular control volume even though it remains part of the registered logical system. This distinction is what allows one directed transfer to be internal in a larger control volume and a boundary transfer in a nested one.

A transfer is represented by a non-negative magnitude plus explicit direction:

`source_component -> target_component`

For a selected control volume:

- outside -> inside contributes to boundary input;
- inside -> outside contributes to boundary output;
- inside -> inside is an internal-transfer diagnostic and cancels from the outer conservation residual;
- outside -> outside does not affect that control volume.

This makes the same directed transfer reusable for nested control volumes without changing sign conventions.

## Conservation identity

For any selected control volume, EB-I01 reports:

`residual = delta_storage - boundary_input + boundary_output`

A closed balance has residual zero within the numerical policy chosen by the caller. EB-I01 itself does not introduce an acceptance tolerance or silently relax a failed balance.

The test fixture demonstrates a soil plus canopy system in which a soil -> canopy transfer is internal for the combined control volume, but becomes a boundary output for the soil-only volume and a boundary input for the canopy-only volume.

## Transaction contract

Energy accounting is trial-local until the physical kernel transaction is accepted.

The lifecycle is:

1. begin an energy trial from explicit lineage, origin revision and `[t0,t1]`;
2. record directed energy transfers and final component storage;
3. optionally project nested control-volume balances while the trial event stream exists;
4. prepare the trial, which freezes the aggregate whole-system energy balance and consumes the detailed trial event stream;
5. let F-KT perform the physical commit through the existing accepted-commit receipt path;
6. publish the prepared energy balance only if the `fmr_accepted_commit_receipt_t` exactly matches lineage, origin revision and interval;
7. on rollback or abort, publish nothing.

The receipt remains the physical commit authority. EB-I01 cannot independently accept a physical candidate.

## Memory ownership

The event stream and component arrays are worker/job scratch for an active trial. They are not added to the persistent physical column state. The committed energy record is deliberately compact: transaction provenance plus the aggregate whole-system energy balance.

Arbitrary nested control-volume reconstruction after commit is therefore not claimed by EB-I01. If later audit or diagnostics require selected nested balances to persist, that should be added as an optional diagnostics/history product rather than retaining every trial transfer graph on every column.

## Relationship to mass accounting

Energy accounting is orthogonal to the existing mass-conservation and groundwater-interface mass ledgers. EB-I01 changes no existing mass source, mass acceptance rule or groundwater flux sign convention.

The qualification gate recompiles and executes the unchanged FMR18 accepted-commit-receipt/mass transaction test without linking the EB-I01 modules.

## Non-claims

EB-I01 does not claim:

- complete wiring of current SWAP heat, canopy, surface or phase-change processes into this ledger;
- scientific qualification of a heat solver;
- large-batch MultiSWAP throughput or memory qualification;
- concurrent-worker race/stress qualification;
- bounded-cost production behavior for arbitrarily large transfer graphs;
- runtime-wide reporting or serialization admission;
- MODFLOW-cell or tile-fraction energy aggregation;
- independent verifier qualification;
- current-canonical admission.
