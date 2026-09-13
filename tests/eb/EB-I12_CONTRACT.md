# EB-I12 Accepted Bottom Water-Thermal Substep Carrier Contract Freeze

## Status and authority

Restart authority:

`integration/f-ci-canonical@df51575e18777856a47a5d0d1e2e1c7456be4601`

Decision:

`DESIGN_FROZEN_NO_PRODUCTION_IMPLEMENTATION`

EB-I12 is a contract-freeze workunit. It changes no production source and qualifies no energy calculation. Its purpose is to freeze the narrow information-lifetime and transaction semantics required before production bottom advective-energy accounting can be implemented safely.

The contract incorporates the EB-I11 source finding that current canonical already has accepted bottom-water exchange and restricted thermal state, but loses the temperature history associated with individual accepted model advances when a transaction is accepted through a two-half route or when an outer canonical interval contains multiple accepted transactions.

## Blocking source fact

Current F-KT can accept a transaction using `TX_ROUTE_TWO_HALF`.

In that route:

- `half1_outcome%bottom_outward_exchange_native` and `half2_outcome%bottom_outward_exchange_native` are summed into one `accepted_bottom_outward_exchange_native`;
- the final physical transaction state is the state after the second half;
- the first-half thermal state is no longer available after `execute_reference_interval()` returns.

Therefore neither of these post-transaction shortcuts is admissible as a general production rule:

- aggregate accepted bottom water multiplied by the terminal bottom-node temperature;
- reconstructing the missing first-half temperature by re-running the physical model.

The first is physically wrong when donor temperature varies. The second violates the bounded-cost and no-extra-production-solve direction of the architecture and can also create provenance ambiguity.

## Architectural decision

The next production implementation shall preserve bottom water-thermal provenance through **worker-local transaction attempt context**, not through persistent column state and not by adding energy-specific state to the F-KT kernel.

The existing `transaction_attempt_context_t` lifecycle is the governing mechanism because F-KT already:

1. captures a checkpoint attempt context;
2. restores it before alternative full/half/retry trials;
3. captures the context reached by the two-half route;
4. restores the selected route context before accepting that route;
5. restores the checkpoint context when a trial is rejected.

A thermal provenance carrier attached to the serialized physical model's attempt context therefore inherits the same route selection and rollback semantics as the physical trial without changing committed physical state.

## Required carrier semantics

A future implementation shall carry a bounded sequence of **model-advance bottom thermal transfer samples** for the candidate route under construction.

Each sample must identify at least:

- sample interval `t0`, `t1`;
- authoritative signed bottom liquid-water amount using the existing convention, positive outward from SWAP;
- donor-side classification: local SWAP water, external water, or no donor required for exact zero transfer;
- availability/completeness of donor thermal provenance;
- sufficient donor thermal information to support a later qualified temporal quadrature without reconstructing discarded trial state.

For local outward flow, EB-I12 freezes the minimum retained thermal information as both bottom donor-node endpoint temperatures for that model advance:

- local bottom temperature at the start of the model advance;
- local bottom temperature in the successful thermal trial state at the end of the model advance.

EB-I12 deliberately does **not** collapse these two endpoint values into a midpoint, arithmetic mean, terminal value or flux-weighted value. Selecting the temporal donor-temperature quadrature is a later scientific decision.

For inward flow, the donor is external to SWAP. Current canonical does not provide an authoritative external groundwater/deep-vadose water temperature at this seam. A future implementation may therefore record the sample as thermally incomplete, but it must not substitute local bottom-soil temperature, air temperature or zero enthalpy.

Exact zero bottom transfer requires no donor temperature.

## Why a sequence is retained instead of one scalar temperature

A single aggregate water amount plus one aggregate or terminal temperature is insufficient to preserve the information needed for a later conservative quadrature.

The carrier therefore retains accepted-route sample granularity in worker scratch until the outer candidate is complete. This allows a later workunit to qualify, for example, a constant-property liquid-water sensible-energy quadrature without first committing to that formula here.

The carrier is bounded by numerical configuration. Under the current full-versus-two-half reference transaction route, one accepted transaction contributes at most two model-advance samples. Across a canonical interval, storage is therefore bounded by a small multiple of `max_committed_substeps`. This is worker/job-local scratch, not per-column persistent state.

A future alternative solver or transaction policy may require a different internal sampling pattern. The public semantics shall be accepted-route transfer samples, not assumptions about Richards, HeadCalc or the current two-half implementation.

## Transaction lifecycle

The required lifecycle is:

1. outer interval preparation resets the worker-local carrier;
2. each successful physical model advance appends provisional sample data to the current attempt context only after the hydraulic and restricted thermal trial data needed by that sample are valid;
3. full/half/retry route changes use existing attempt-context capture/restore, so unselected or rejected samples disappear with the rejected route;
4. after each accepted transaction, only samples belonging to that selected route remain in the model context;
5. if the complete requested outer `[t0,t1]` interval fails, no carrier payload is public;
6. if the outer kernel trial completes, the backend may snapshot the complete carrier as **candidate-scoped ephemeral result metadata**;
7. that metadata is not inserted into `kernel_candidate_state_t` physical continuation state;
8. runtime publication is sparse and occurs only after the existing outer candidate commit succeeds and exact accepted-transaction provenance is available;
9. a rejected outer candidate, failed commit or rollback publishes no accepted carrier record.

EB-I10R2 demonstrates one structurally atomic outer publication shape on its owner branch, but EB-I12 does not promote EB-I10R2 to canonical authority and does not make a production dependency on an unadmitted branch.

## Data-category decision

The carrier sequence is temporary numerical/runtime data. It is not physical continuation state.

A completed accepted carrier record is result/provenance data. It is not a second water-mass ledger.

Liquid-water density, heat capacity and reference temperature belong to immutable energy configuration when an enthalpy law is later composed. They do not belong in the carrier state.

External donor-water temperature belongs to forcing or to a coupler/component exchange contract, depending on source ownership. SWAP kernel code must not know whether that source is MODFLOW, a deep-vadose transfer zone or another component.

## Relationship to existing owner EB work

EB-I04 provides an owner-qualified constant-property liquid-water sensible-enthalpy primitive. EB-I06 provides an owner-qualified direction-based donor selector. EB-I08 and EB-I09 provide owner-side external and local donor-temperature contracts. None is current-canonical authority at this workunit's restart point.

EB-I12 therefore freezes information preservation and transaction semantics only. It does not copy those owner-only formulas into canonical production code and does not claim that their scientific choices have been independently admitted.

EB-I05 separately shows that the current De Vries sensible storage report `C(theta_avg)*DeltaT` omits the composition-storage term of the exact linear mixture state law when water content changes. Bottom advective-energy accounting must therefore not be advertised as closing the total soil energy balance until storage composition and other missing routes are reconciled as well.

## MultiSWAP and memory rules

A future implementation shall satisfy all of the following:

- no permanent carrier array in every logical column;
- scratch belongs to the worker/backend execution object;
- carrier activation is optional and scoped to columns/routes requesting thermal-energy provenance;
- sparse accepted records are returned only for requested columns;
- immutable thermal/energy parameters remain shareable through existing parameter/template mechanisms;
- no extra Richards or restricted thermal solve is permitted merely to reconstruct carrier history.

## Coupling boundary

The carrier uses the existing signed SWAP bottom-water amount and does not reinterpret it as MODFLOW recharge, groundwater-cell exchange or deep-vadose outflow.

Runtime/coupler code remains responsible for system composition, tile fractions and any transfer-zone mapping. For direct SWAP-MODFLOW exchange, later energy coupling must use the same mass-conserving interface transfer that satisfies the water coupling contract. For a deep-vadose transfer zone, thermal transport through that component requires its own mass- and energy-conserving contract.

## Scientific decisions explicitly deferred

EB-I12 does not choose:

- a temporal interpolation or quadrature for local donor temperature;
- a groundwater or deep-vadose donor-water temperature model;
- a liquid-water enthalpy reference temperature;
- temperature-dependent water properties;
- whether energy-accounting incompleteness rejects an otherwise valid hydrologic transaction or only marks the energy result incomplete;
- internal soil-face advection;
- drainage, root, surface-water, precipitation, irrigation, snowmelt, evaporation or vapor energy;
- a correction to the current restricted soil-temperature governing equation;
- a complete energy ledger.

## Hard nonclaims

EB-I12 does not qualify:

- Joule calculation;
- bottom advective-energy quadrature;
- a closed soil or land-column energy balance;
- external groundwater temperature;
- route-specific donor-node physics beyond the bottom-node endpoint data preservation decision for local outward flow;
- independent verification;
- canonical admission;
- parallel-backend implementation;
- GPU/SIMD throughput.

## Next implementation gate

The next code workunit may implement this carrier only if it proves all of the following with adversarial tests:

1. a full trial followed by a selected two-half route retains only the two half-route samples;
2. a rejected attempt leaves no sample residue;
3. retry restores exactly the checkpoint carrier state;
4. an outer interval failure publishes nothing even after earlier internal accepted transactions;
5. an accepted multi-substep outer candidate retains the exact ordered sample sequence from all selected routes;
6. exact zero transfer does not require thermal provenance;
7. outward transfer uses local bottom thermal endpoints from the same physical model advance;
8. inward transfer without explicit external thermal provenance is marked incomplete and never silently substituted;
9. no production physical solve count increases because of carrier collection;
10. committed physical state, water mass accounting and F-KT candidate semantics remain byte-for-byte or behaviorally unchanged outside the new optional result path.
