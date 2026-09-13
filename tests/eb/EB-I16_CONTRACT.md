# EB-I16 External Bottom Thermal Binding Contract

Status: DESIGN_FROZEN_NO_PRODUCTION_IMPLEMENTATION

Base authority: `0181b7b674cc89d729e361dafc1135b719e23a7d` (qualified EB-I15 exact head).

## Purpose

EB-I16 freezes the source-agnostic contract by which a runtime/coupler may supply external liquid-water donor temperature provenance for an already accepted bottom-transfer sample. It closes the design gap identified by EB-I14 and EB-I15 for inward bottom water without creating a second water-exchange authority.

This workunit changes no production source and admits no new production physics.

## Existing authorities preserved

The following production authorities are inputs to this design and are not modified by EB-I16:

- `mod_fmr_bottom_thermal_carrier`: accepted bottom thermal samples and sample ordering.
- `mod_groundwater_coupling_contract`: generic groundwater interface convention and coupling lineage.
- `mod_groundwater_exchange_service_contract`: transactional groundwater candidate lineage and publication lifecycle.
- EB-I14: first-order bottom advective-energy quadrature semantics.
- EB-I15: candidate-scoped sensible-energy evaluator and fail-closed external-inflow behavior.

The accepted water transfer remains the sole mass authority. A thermal binding MUST NOT own, duplicate, alter, integrate, rescale, infer, commit, or rebook bottom water quantity or flux.

## Frozen binding model

For each accepted `FMR_BOTTOM_THERMAL_DONOR_EXTERNAL` sample with strictly negative outward-positive water exchange, the runtime/coupler may provide one supplemental thermal binding containing only information needed to resolve the external donor temperature for that accepted sample.

A future implementation SHALL identify a binding by:

1. an opaque accepted-candidate lineage identity supplied or composed by runtime/coupler infrastructure; and
2. the one-based accepted thermal sample ordinal within that candidate.

The binding payload SHALL contain a finite donor temperature in degrees Celsius and MAY carry an opaque source-provenance token. It SHALL NOT contain or become an alternative owner of the accepted water amount.

The energy layer does not need to understand the internal fields used to construct the opaque lineage identity. Existing groundwater lineage may contribute to such an identity, but no groundwater-specific type is required by the energy evaluator.

## Why interval-only identity is insufficient

`fmr_bottom_thermal_candidate_t` currently exposes candidate interval and ordered samples, but no explicit candidate lineage token. Retry, step-doubling, adaptive substeps, predictor/corrector trials, or repeated evaluation of the same time interval can produce distinct candidates that share numeric `[t0,t1]` values.

Therefore `[t0,t1]`, floating time equality, water-transfer magnitude, sign, or donor class alone MUST NOT be treated as a sufficient binding key.

EB-I16 freezes explicit lineage plus sample ordinal as the future implementation requirement. It does not retrofit a token into production types in this design-only workunit.

## Source ownership and composition

External donor temperature is owned by the component supplying the incoming water and is bound by runtime/coupler composition. SWAP kernel/process physics MUST NOT know whether that source is MODFLOW, a deep-vadose transfer zone, another groundwater implementation, an open-water component, a tile aggregator, or another external component.

Consequently:

- no MODFLOW-specific donor-temperature field or enum belongs in SWAP kernel/process contracts;
- no tile fraction or deep-vadose identity belongs in the SWAP thermal evaluator;
- no mandatory temperature field is added to the generic groundwater mass-exchange contract by this workunit;
- optional external thermal functionality consumes memory and work only when requested and applicable.

## Temporal semantics

EB-I14 freezes terminal local donor temperature because current SWAP accepted water amount is a terminal-flux/right-endpoint rectangle. That local rule does not authorize SWAP to invent temporal interpolation for an external component.

For external inflow, the provider/coupler SHALL supply an already-qualified scalar donor temperature for the exact accepted transfer sample. The provider owns how that scalar is derived from its own state and temporal discretization. The binding must state only the sample-resolved value consumed by the energy evaluator.

A single coupling-window temperature MUST NOT be silently reused for every accepted inflow sample. Reuse is permissible only if the provider explicitly binds and certifies that same value separately for each applicable accepted sample under its own qualified temporal semantics.

## Validation and fail-closed rules

For every external-inflow sample requiring sensible-energy evaluation:

- exactly one matching binding is required;
- candidate lineage must match exactly;
- sample ordinal must match exactly and refer to an external-inflow sample;
- donor temperature must be finite;
- duplicate bindings are invalid;
- stale or foreign-lineage bindings are invalid;
- missing bindings are incomplete;
- bindings attached to local-outflow or exact-zero samples are invalid for external-donor resolution.

No fallback may infer donor temperature from local bottom temperature, reference temperature, local hydraulic head, flux sign, neighboring samples, an outer-window average, zero, or any other implicit default.

Exact zero transfer requires no donor binding and contributes exactly zero sensible advective energy.

When a required external binding is absent or invalid, the total bottom sensible-energy result remains unavailable/fail-closed. While this energy path remains diagnostic and non-governing, such thermal incompleteness MUST NOT retroactively reject, mutate, or recommit an otherwise accepted mass-conserving hydrologic transaction.

## Transactional semantics

Bindings are candidate-scoped supplemental provenance. A binding for a rejected, rolled-back, superseded, or stale candidate MUST NOT be accepted for a different candidate, even if interval, water amount, or sample count happen to match.

A future implementation SHALL permit cheap discard/rebuild on retry and SHALL NOT require persistent per-column history of external donor temperatures. Candidate thermal provenance is not committed physical SWAP state.

Accepted-energy publication, energy-ledger persistence, restart persistence of published energy, and thermal feedback into governing physics are separate later qualification boundaries.

## MultiSWAP and performance

The logical API may be object-oriented, but a future implementation may store bindings in compact arrays, pools, or batches. Optional external thermal provenance SHALL allocate and execute only for columns/samples that need it. No heavy solver instance, extra physical solve, or reconstructed groundwater trial is authorized to obtain donor temperature.

## Scientific/accounting rule after successful binding

Once a valid per-sample external donor temperature `T_adv` is bound to an accepted external-inflow sample, EB-I14/EB-I15 sensible-energy accounting applies without changing the accepted water amount:

`E_b = 0.01 * rho_w * c_p_w * Q_b * (T_adv - T_ref)`

where `Q_b < 0` for inward water under the frozen outward-positive convention. Energy sign therefore follows the already accepted water orientation and sensible enthalpy difference.

## Hard nonclaims

EB-I16 does NOT claim:

- a production binding type or runtime implementation;
- automatic retrieval of temperature from a groundwater model;
- MODFLOW-specific thermal coupling;
- a new or modified mass-exchange contract;
- a new committed state variable;
- accepted energy publication or restart persistence;
- thermal feedback into the soil-water or heat solver;
- higher-order temporal accuracy;
- a closed whole-system energy balance;
- canonical admission.

## Next implementation boundary

A later workunit may implement a compact source-agnostic candidate binding bundle and extend the EB-I15 evaluator to consume it. That implementation must preserve the sole accepted-water authority, enforce lineage plus sample-ordinal matching, remain fail-closed, and receive separate exact-head qualification before any publication or governing-physics integration.