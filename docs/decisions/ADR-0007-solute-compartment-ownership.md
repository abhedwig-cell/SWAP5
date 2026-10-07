# ADR-0007: Explicit solute compartment ownership beyond conservative mobile salt

Status: **Accepted**

Date: 2026-10-07

## Context

The admitted SWAP5 matrix-solute route owns one conservative dissolved mobile
constituent and advances it transactionally from accepted water-flux traces.
B1.11 additionally contains nonlinear sorption, decomposition, pond solute,
aquifer storage/breakthrough and a water-age tracer.

These capabilities cannot safely be added by changing the meaning of the
existing dissolved-mobile mass array. Sorbed mass, pond mass and aquifer mass
have different storage coefficients, transfer boundaries and restart
requirements. The age tracer has an internal age-production term and is not a
chemical constituent.

## Decision

The existing mobile_salt_state_t remains the authoritative dissolved-mobile
matrix store in its admitted envelope.

Successor SOL01 capabilities use explicit additional stores:

- **sorbed matrix store**: persistent constituent mass associated with the
  solid phase; equilibrium/kinetic algebra may derive concentration relations,
  but the committed mass contribution is explicit;
- **pond solute store**: persistent surface-store constituent mass, coupled to
  accepted pond water and explicit rain/irrigation/runoff/infiltration receipts;
- **aquifer solute store**: persistent mixed aquifer constituent mass with an
  explicit water/storage coefficient and breakthrough receipts;
- **age amount store**: persistent water-age amount. Its concentration-like
  diagnostic is derived from age amount and matching water storage.

Decomposition/decay is an explicit external solute-mass sink. It is never
implemented as an unbooked concentration rescaling.

Every transfer between dissolved, sorbed, pond and aquifer stores is booked
once as an equal and opposite internal transfer. Boundary export/import and
decay are booked as external output/input. Whole-system qualification checks
the sum of all participating stores plus external receipts.

## Runtime layout identity

Reactive SOL01 state is a distinct restart/template topology. It must not be
stored under either existing `FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED` or
`FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED_MACROPORE`.

A successor production binding therefore requires a new explicit solute layout
identity whose readiness contract includes every persistent reactive store
enabled by that layout. Existing mobile-only layout validators remain
fail-closed if reactive companion fields are present. This prevents a warm
restart from changing the meaning of persisted state while retaining the same
template capability id.

The first reactive layout may compose matrix dissolved mass with sorbed matrix,
pond and age stores. Aquifer storage may be carried only as inert persisted
state until the SWBR reference-correction decision is approved; non-zero
aquifer process mutation remains prohibited.

## Accepted water carrier

All SOL01 stores may consume accepted water storage/flux information from the
existing water owner. They do not own or modify water. Rejected hydraulic
trials therefore cannot publish solute transfers based on rejected water
trajectories.

## Source defect boundary

The literal B1.11 SWBR=1 aquifer block has a reproduced out-of-bounds access
after the compartment loop. This ADR does not guess a replacement index or
coefficient.

The intended aquifer capability remains in scope, but production implementation
requires an explicit source-defect decision that establishes:

1. the physical aquifer water/storage coefficient;
2. rate-versus-accumulated units for all participating terms;
3. zero-flow and signed drainage behaviour;
4. a mass-conservative multi-substep oracle.

Until that decision is qualified, aquifer breakthrough remains unadmitted.

## Water age

SWSOLU=2 is implemented as a separate age-amount owner. The age-production
source is internal to that owner and must be source-qualified separately.
Chemical sorption and chemical decay are not applied to the age tracer unless
a later exact source contract explicitly requires them.

## Restart and transaction consequences

All stores that influence a later accepted result are persistent restart state.
Concentrations, equilibrium factors and reaction-rate workspace are derived
unless source evidence establishes persistent physical history.

A failed or rejected attempt leaves every committed solute store unchanged.
Partial commit of only one compartment is prohibited.

## Consequences

This decision supplies the ownership contract for
SW431-SALT-SORPTION, SW431-SALT-DECAY, SW431-SALT-AQUIFER,
SW431-SALT-POND and SW431-AGE-TRACER.

It does **not** admit their B1.11 equations. Sorption, decay, pond transfer,
aquifer breakthrough and age production each still require exact source
oracles and bounded production qualification.

## Affected invariants

- one owner per persistent physical store;
- accepted/trial state isolation;
- explicit mass conservation across internal transfers and external receipts;
- restart reconstructs all persistent physical state;
- solute processes consume accepted water carriers without acquiring water ownership;
- source defects are not silently copied or guessed around.
