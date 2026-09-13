# EB-I10R Atomic Accepted Water-Thermal Transaction Binding

## Authority

Restart authority: `integration/f-ci-canonical@2a0db2524fba6e258316ce82630c60ea1c9c673a`.

EB-I10R supersedes the blocked post-hoc EB-I10 design on `work/eb-i10-accepted-water-thermal-provenance-binding`. The blocked design reduced candidate identity to lineage, origin revision and `[t0,t1]`. Current F-KT permits more than one candidate materialization from the same committed origin and interval, so that tuple cannot prove exact candidate materialization identity by itself.

## Purpose

EB-I10R provides one narrow runtime composition seam for thermal-enabled serialized MultiSWAP columns. It answers one question:

- did this runtime call accept and commit a physical transaction whose canonical candidate contained the restricted soil-temperature state produced in the same physical trial lifecycle as the water state?

The answer is represented by `accepted_water_thermal_transaction_t` and is only materialized by `fmr_run_serialized_multiswap_with_water_thermal_binding` after the existing serialized runtime returns a ready F-MR18 accepted commit receipt.

EB-I10R does not calculate or publish water-transfer amounts, temperature profiles, enthalpy or energy.

## Why the old post-hoc token design is rejected

The current F-KT candidate contract exposes lineage id, origin revision and origin interval, but no unique candidate-materialization id. F-MR18 receipts carry the same origin tuple plus the committed revision. Two different retries or alternative candidates can therefore share the same exposed tuple before one is committed.

A public API of the form `capture candidate A -> capture candidate B -> authorize either token later with receipt A` is structurally unsafe because tuple equality cannot distinguish the two materializations.

EB-I10R removes that authorization shape entirely. There is no public candidate-capture API, no public receipt-authorization API and no public scalar constructor for accepted provenance.

## Atomic lifecycle

The only production entry point is:

`fmr_run_serialized_multiswap_with_water_thermal_binding(...)`

For the requested thermal column ids it performs the following lifecycle:

1. validate all requested ids and thermal topology before any physical trial;
2. call the existing `fmr_run_serialized_physical_multiswap` exactly once;
3. request F-MR18 receipts for exactly the requested thermal column ids;
4. let the existing runtime internally create the F-KT candidate, validate mass accounting, commit that exact candidate and emit the receipt;
5. after the runtime returns, require ready receipts to agree with the committed column result and committed-state lineage, revision and time;
6. only then materialize a ready accepted water-thermal transaction record.

The caller never supplies a candidate or receipt to EB-I10R. Therefore a receipt from one internal candidate cannot be reused after the fact to authorize a different same-origin candidate through this seam.

## Thermal authority

Prevalidation requires all requested thermal columns to use:

- `FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE`;
- `soil_temperature_active = .true.` in the selected physical parameter set;
- an allocated thermal parameter contract;
- allocated thermal forcing.

Current canonical F-MR39 runtime composition runs Richards first, constructs the hydraulic end view from that solve, executes the restricted soil-temperature trial, places the accepted thermal trial state in the same local physical transaction state, and only then allows the outer physical transaction to complete. A thermal failure therefore rejects the complete candidate.

EB-I10R relies on that already-admitted F-MR39 authority and does not duplicate thermal physics.

## Water authority

Water mass accounting and candidate publication remain entirely owned by existing F-KT/F-MR serialized runtime. EB-I10R does not recompute, alter or repair water mass. The wrapper introduces no additional physical solve and no second commit path.

This workunit does not yet bind a specific water-transfer amount or route to a temperature payload. That later payload-level composition must itself be created inside an equally atomic lifecycle and may use this transaction seam as authority.

## Accepted record semantics

A ready `accepted_water_thermal_transaction_t` exposes only:

- lineage id;
- origin revision;
- committed revision;
- accepted interval `[t0,t1]`.

The containing sparse record adds the logical `column_id`.

These values are descriptive metadata for the transaction that this wrapper itself just caused to be accepted. They are not a general-purpose detached authorization capability for arbitrary external payloads.

A requested thermal column that is physically rejected receives a record whose transaction is not ready. Invalid binding requests fail before the physical runtime is entered and return no records.

## MultiSWAP and cost

The binding request is sparse. Only requested thermal column ids receive accepted-record metadata and F-MR18 receipt output. Nonthermal columns retain their existing execution path and optional-state compactness.

EB-I10R performs no extra Richards solve, no extra thermal solve and no candidate snapshot. Work added around an accepted column is fixed-size metadata validation.

## Failure semantics

Request-level failures are fail-closed before physical execution:

- duplicate or non-positive thermal ids;
- unknown or ambiguous logical column ids;
- missing or ambiguous templates;
- invalid state/parameter/forcing handles;
- non-ready committed state;
- requested column not configured with the admitted restricted soil-temperature topology.

Physical rejection is not converted into a binding failure. It remains the existing physical transaction result, with no ready accepted water-thermal record for that column.

After a ready F-MR18 receipt exists, disagreement between receipt, result and committed state is treated as an internal invariant violation rather than a recoverable EB-I10R status, because the physical commit has already occurred and silently returning contradictory provenance would be unsafe.

## Hard nonclaims

EB-I10R does not qualify:

- a water-transfer amount or route contract;
- a temperature-field payload contract for energy consumers;
- donor-node selection;
- external donor-water temperature;
- liquid-water sensible enthalpy calculation;
- Joule accounting or an energy ledger;
- vapor, snow, ice or latent phase-change energy;
- route-specific drainage, root, runoff, macropore or groundwater thermal physics;
- a closed energy balance;
- parallel-backend provenance publication;
- independent qualification;
- canonical admission.

## Required next boundary

A later advective-energy workunit may consume EB-I10R only if the authoritative water-transfer payload and thermal donor information are produced and consumed inside a structurally atomic accepted-transaction composition. It must not reconstruct exact-trial identity later by comparing only lineage, revision and interval metadata.
