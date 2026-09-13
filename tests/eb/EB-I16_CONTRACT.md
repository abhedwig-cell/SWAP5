# EB-I16 — External Bottom Donor Thermal Binding Contract

## Status and restart authority

Restart authority:

`work/eb-i15-bottom-sensible-energy-evaluator@0181b7b674cc89d729e361dafc1135b719e23a7d`

Decision:

`DESIGN_FROZEN_NO_PRODUCTION_IMPLEMENTATION`

EB-I16 freezes only the runtime/coupler contract required to supply explicit thermal provenance for inward bottom liquid-water samples already materialized by EB-I13. It does not create a second groundwater exchange, a second water-mass ledger, a MODFLOW-specific SWAP interface or accepted energy publication.

## Existing mass-side authority

Current restart authority already contains three relevant runtime capabilities:

1. `mod_groundwater_coupling_contract` freezes the public interface sign convention and coupling window. `q_swap > 0` means water leaves SWAP; `q_groundwater = -q_swap` is exact action/reaction.
2. `mod_groundwater_exchange_service_contract` owns groundwater checkpoint, trial candidate, discard and prepare/commit/abort lifecycle. Candidate identity is service-owned and cannot be reconstructed safely from public scalar metadata alone.
3. `mod_groundwater_interface_mass_ledger` owns staged and committed interface water exchange and binds it to coupling/candidate lineage. It remains the sole mass-booking authority.

EB-I16 therefore adds no water amount to the thermal contract. The signed EB-I13 sample remains the authoritative SWAP-side amount used by the energy evaluator. A thermal provider is not allowed to restate, correct, normalize or commit that amount.

## Thermal-only sidecar

The future implementation shall expose a generic runtime/coupler-side external donor thermal provider. Conceptually, one lookup request contains only identity and time information required to ask for the donor-water temperature belonging to the exact inward sample under evaluation. It must not contain an authoritative water amount.

The minimum result semantics are:

- available or unavailable;
- finite donor liquid-water temperature in degrees Celsius when available;
- provider-side source/candidate epoch or equivalent one-shot identity sufficient to reject stale provenance;
- no water quantity, flux or mass balance field.

The physical source may be direct groundwater, a deep-vadose transfer component or another runtime-composed external source. That mapping remains outside the SWAP kernel.

## Direction rule

For each EB-I13 accepted-route sample:

- `Q_swap > 0`: water leaves SWAP. The donor is local. EB-I15 continues to use the EB-I13 local terminal temperature. The external provider must not be queried.
- `Q_swap = 0` exactly: no liquid water is transported. No donor temperature is required and the external provider must not be queried.
- `Q_swap < 0`: water enters SWAP. The donor is external. A finite external donor-water temperature is required before the bottom sensible-energy total may be marked complete.

There is no small-transfer tolerance. Every finite nonzero inward sample requires external thermal provenance.

## Temporal convention

EB-I14 freezes current-reference temporal accounting for the current production discretization. The SWAP-side water amount is formed from the terminal/current-reference bottom flux over the model advance. Therefore the external donor thermal value paired to that sample must represent the same current/reference instant for that model advance, operationally the donor-water temperature at the sample's `t1` reference instant unless a future jointly qualified water/energy discretization replaces both conventions together.

An interval-average, start-point value or arbitrary groundwater temperature snapshot must not silently substitute for this current-reference value.

## Candidate identity and anti-replay rule

EB-I10R2 established that lineage, origin revision and `[t0,t1]` alone do not uniquely identify one candidate materialization. The groundwater exchange service independently confirms the same architectural direction through opaque checkpoint/candidate/prepared tokens and one-shot reservation generations.

Therefore the future thermal binding must be evaluated inside the same runtime candidate lifecycle as the water/groundwater trial to which it belongs, or through an equally strong opaque one-shot handle issued by that lifecycle.

A detached API that accepts only scalar lineage/window/revision metadata and later authorizes thermal provenance is forbidden.

A copied, stale or replayed thermal handle must fail closed. Thermal provenance from predictor candidate A may not be reused for corrector/retry candidate B merely because the visible coupling window and origin revisions are equal.

## Coupling to existing groundwater authority

For direct groundwater coupling, the runtime/coupler may obtain the external temperature from the same component that owns the groundwater exchange candidate. That does not make temperature part of the water mass contract.

The water exchange service remains authoritative for groundwater state/exchange candidate lifecycle. The mass ledger remains authoritative for committed interface mass. The thermal sidecar contributes only donor-temperature provenance for energy accounting.

For deep-vadose routing, the transfer component must supply the donor temperature at the SWAP-facing interface if it claims complete energy transfer. The downstream groundwater temperature is not automatically the SWAP-facing donor temperature. No stored water or energy may disappear when composition changes between direct and transfer-zone routes.

## Failure semantics

If an inward sample has missing, non-finite, stale, mismatched or replayed thermal provenance:

- hydrologic and groundwater mass acceptance is not retroactively invalidated solely for this reason;
- the bottom sensible-energy result is incomplete/unavailable;
- the missing contribution is never substituted by zero, local SWAP temperature or air temperature;
- diagnostics must identify the incomplete external donor route.

The future runtime may adopt a stronger application policy that requires complete energy accounting before a coupled application accepts a window, but such policy is a separate explicit qualification. EB-I16 does not silently change physical transaction acceptance.

## Publication boundary

EB-I16 does not authorize accepted energy publication. Candidate-scoped energy may be evaluated once all sample donor temperatures are complete, but publication into a committed energy result/ledger must remain coupled to the exact accepted outer candidate and its commit lifecycle.

A rejected candidate, aborted prepared exchange, rollback or failed outer interval publishes no accepted energy record.

## MultiSWAP and state ownership

The thermal sidecar is opt-in and sparse. It must not allocate persistent provenance state for every logical column. Candidate/request data belong to worker/runtime scratch or sparse candidate-scoped result metadata.

Provider/source configuration may be shared by IDs/references. No thermal sidecar data is physical continuation state unless a separate physical component, such as a deep-vadose transfer zone, independently owns thermal storage that is physically required for continuation.

## Required implementation gate

A later implementation may proceed only if executable qualification proves at least:

1. inward nonzero sample plus matching current-reference external temperature becomes thermally complete;
2. missing temperature remains incomplete;
3. non-finite temperature remains incomplete;
4. smallest tested nonzero inward transfer still requires provenance;
5. exact zero does not query the provider;
6. local outward flow does not query the provider;
7. current-reference `t1` value is used, not an interval mean or start value;
8. provider request/result carries no water amount or flux authority;
9. stale/mismatched/replayed provider identity fails closed;
10. two distinct same-origin candidates cannot share a detached thermal authorization;
11. no additional physical SWAP solve is introduced;
12. no committed water mass, groundwater exchange or hydrologic acceptance semantics change;
13. no persistent provenance array is added per logical column;
14. accepted energy is still not published before exact candidate commit authority exists.

## Hard nonclaims

EB-I16 does not qualify:

- a production thermal provider implementation;
- a groundwater-temperature physical model;
- a deep-vadose temperature model;
- MODFLOW temperature transport;
- heat conduction across the SWAP-groundwater interface;
- a second water exchange contract;
- accepted energy commit/publication;
- energy restart state;
- a closed soil or land-column energy balance;
- canonical admission.
