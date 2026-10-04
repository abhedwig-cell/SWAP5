# PPA-WU05-E state-layout design decision

Date: 2026-10-04  
Status: `STATE_LAYOUT_SCAFFOLD_IMPLEMENTED_UNQUALIFIED_NOT_CANONICALLY_ADMITTED`  
Work unit: `PPA-WU05-E`  
Baseline: `integration/f-ci-canonical@9605fbb1622d96f4691117f66264f13b6dd3a47b`

## Decision

Represent salinity as an optional, typed physical-state component carried inside the same per-column physical object as the matching water state. Give that component an independent solute-layout discriminator in the FMR template/restart identity, orthogonal to the existing optional physical-continuation layout.

Do not create a separately committed salinity sidecar, add a second transaction revision, or make Jarvis an owner of salt state. The generic kernel remains unchanged: it commits one polymorphic physical state under one lineage, revision, and accepted time.

This is a work-unit design decision for the branch. It is not a canonical interface acceptance or production admission.

## Why this representation

The current transaction boundary clones and commits one polymorphic physical-state object, and Restart v2 serializes that same committed payload. FMR already has separate optional continuation families with explicit clone and restart rules. A salinity-only subtype would make it difficult to express salt together with other continuation families and risks a growing product of concrete types. An independently discriminated component makes salt's presence explicit while retaining one atomic water/salt state object.

## Required contract

1. **Ownership:** the FMR physical state owns the optional salt mass component. The mobile salt process alone computes candidate salt transport and salt receipts. Jarvis receives a concentration view and cannot mutate salt state.
2. **Authority:** for the restricted E1 envelope, node salt mass is authoritative. `CML` is derived from salt mass and water content from the same physical state and revision. Do not separately persist a potentially stale concentration vector as authority.
3. **Atomic transaction:** candidate water and candidate salt occupy the same polymorphic physical candidate. Existing F-KT lineage/revision/time validation accepts or rejects both together. Retry starts from the unchanged accepted object.
4. **Clone coverage:** every current FMR physical-state clone implementation must preserve the optional salt component; copying only the base hydraulic fields is insufficient. Clone validation must preserve concrete continuation family as well as salt allocation and values.
5. **Layout identity:** add an independent typed salt-layout identity to the FMR template identity and restart record. Initial restricted values are `NONE` and `MOBILE_DISSOLVED_SINGLE_CONSTITUENT`. Existing thermal, snow, macropore, evaporation, and other optional-state layout identifiers remain independent.
6. **Restart compatibility:** the next serialized FMR restart schema must identify the new component. Export emits the new schema. Restore may accept the prior v2 schema only for records with no salinity component and a matching salinity-disabled target. A v2 record must never initialize an active salinity layout by reconstructing or guessing salt mass.
7. **Activation:** immutable column parameters select the salt layout. For an active layout, restore and trial startup reject absent, wrongly sized, nonfinite, or negative committed mass. For an inactive layout, an allocated salt component is rejected. Existing disabled routes retain their current physical state layout and results.
8. **Transport clock:** salt candidates advance at accepted Richards physical substeps, using the exact water start/end contents, face water fluxes, root sink, and substep duration. An interval-end-only reconstruction is not an acceptable replacement when internal retries/substeps affect flux history.
9. **Separate ledgers:** water closure and salt closure have different units and receipts. A salt rejection invalidates the whole physical candidate; it does not modify or back-correct the accepted water receipt.

## Initial coexistence envelope

The new layout dimension is independent by design. For the first qualified active route, the tested physical continuation combinations must be declared explicitly. The initial implementation may fail closed for unsupported salinity-plus-continuation combinations, but it must not silently strip salt during a clone or restart. Salinity-disabled cases continue to cover all existing admitted layouts and remain subject to their current preservation gates.

Before salinity is admitted alongside an optional state family, add at least one transaction and restart test proving the family and salt component survive together. Walsum D3 and oxygen composition are crop/root process routes and must remain available in the selected E1 root-stress integration profile.

## Implementation sequence and gates

1. Add the independent layout identity to template identity and restart records, with v2 disabled-only compatibility.
2. Add the optional salt component to the common FMR physical state and all clone paths; add concrete state/layout validation and initialization/restore tests.
3. Bind the E1 salt transport candidate to live Richards accepted substeps, including the exact candidate root sink. First prove accepted/rejected/discard/retry and independent water/salt receipts.
4. Qualify transport timestep, dispersion and boundary behavior. The current explicit advection-only prototype is not production-ready for general use.
5. Expose a read-only, matching-revision concentration view to root uptake, qualify the pure stress response, and only then extend D2 Jarvis combination rules.

## Implementation checkpoint (2026-10-04)

The branch now implements part of this representation:

- `fmr_b110_physical_state_t` has an optional typed `salt%mass_mg_cm2(:)` component; the base clone copies it.
- `fmr_template_t` carries an independent `solute_state_layout_id`.
- Restart schema v3 carries that identity. v2 restore is rejected when the requested target has active solute state.
- The restart-state contract checks salt allocation, active-node count, finiteness, and nonnegative mass for the mobile-dissolved layout.
- The serialized FMR trial still rejects every active solute layout before physics runs. It does not initialize, advance, or publish a salt candidate.

This is a source-level scaffold, not a qualified transaction. Dedicated clone/layout/serialized-restart tests for active salt, optional-state coexistence, and disabled-layout preservation remain required. Canonical admission and Jarvis integration remain gated by those tests and the PPA-WU05-E qualification manifest.
