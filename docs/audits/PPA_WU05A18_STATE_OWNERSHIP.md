# PPA-WU05-A18 — RFM fast-state / restart ownership adjudication

Date: 2026-10-01

Status: CURRENT_MACROPORE_STATE_MAPPING_REJECTED / DEDICATED_RFM_LAYOUT_REQUIRED

Canonical authority:

    integration/f-ci-canonical@9c6f36ea5ded98a4a9cc36c26d5b3677c8e65ea4

Prerequisites:

    PPA-WU05-A11 through A17 canonically admitted in their bounded scopes.

## Question

Can the A17 MB + terminating-endpoint routing receipt be stored directly in
the existing canonical SWAP macropore continuation state without changing its
physical meaning?

## Existing canonical macropore state

The current:

    macropore_continuation_state_t

owns the migrated standard SWAP macropore information roles:

    num_domains x num_nodes topology
    IC bottom-domain indices
    domain/node sorptivity
    sorption reference theta
    absorption time
    domain/node macropore volume
    domain/node water
    dynamic macropore volume

The serialized backend's storage, temporal-error and admission contracts
interpret these fields according to that standard SWAP topology.

In particular, full/half temporal comparison treats IC bottom-domain identity
as discrete topology and compares the current domain/node water and geometry
arrays directly.

## RFM state meaning is different

The reduced RFM architecture requires different information roles:

    MB fast storage
    terminating endpoint-class storage
    tau_surface
    later, wall-contact event memory when wall exchange is composed

The A17 endpoint classes are defined by explicit structural endpoint depths.
They are not current SWAP IC domain identifiers.

Therefore mapping:

    A17 endpoint class -> existing SWAP macropore domain

merely to reuse the storage arrays would silently impose standard SWAP
domain geometry on the RFM formulation.

That route is rejected.

## Existing transaction architecture is reusable

The rejection is not a transaction-kernel blocker.

The canonical transaction architecture already provides:

    committed state
    clone/checkpoint
    candidate state
    reject/discard
    exactly-once commit
    storage accounting
    temporal comparison hooks

and the FMR runtime already distinguishes physical optional-state layouts from
numerical-continuation layouts.

The runtime core currently recognizes a dedicated:

    FMR_OPTIONAL_STATE_LAYOUT_MACROPORE

for the standard SWAP macropore physical state.

This establishes the correct architectural precedent: RFM should obtain its own
optional physical-state layout rather than overload the standard one.

## Required dedicated RFM state contract

A new RFM optional-state layout should initially contain only information that
is already independently justified:

    mb_water_cm
    endpoint_water_cm(:)
    tau_surface_day

with structural endpoint depths/configuration owned by immutable parameters,
not copied into mutable state.

Wall-contact memory must not be invented in the first layout unless a separate
wall-exchange workunit admits that state contract.

## Exactly-once mass ownership requirement

For any candidate interval:

    storage_start
    + accepted preferential receipt
    - admitted RFM outputs/exchanges
    = storage_end

must be represented once and only once in whole-column mass accounting.

The same A15 preferential receipt must not simultaneously enter:

    standard macropore top input
    and
    RFM fast state.

The two physical options therefore require distinct execution/admission modes.

## Restart requirement

Once an RFM state layout is admitted, restart/checkpoint serialization must
preserve at least:

    MB storage
    endpoint-class storage
    tau_surface

exactly enough that continuation does not depend on hidden event history.

Until that layout is implemented and qualified, A11-A17 remain callable
production primitives rather than a live end-to-end RFM runtime.

## Decision

    EXISTING_STANDARD_MACROPORE_STATE_AS_RFM_CONTAINER = REJECTED
    EXISTING_STANDARD_MACROPORE_LAYOUT_SEMANTICS = PRESERVED
    TRANSACTION_KERNEL_REUSE = SUPPORTED
    NEW_RFM_OPTIONAL_PHYSICAL_STATE_LAYOUT = REQUIRED
    SHARED_STANDARD_AND_RFM_TOP_INPUT = FORBIDDEN
    LIVE_RFM_RUNTIME = NOT YET AUTHORIZED

## Next safe workunit

PPA-WU05-A19 should implement and qualify the minimal dedicated RFM physical
state object and candidate receipt semantics without yet wiring it into the
serialized backend.

The first A19 gate should cover:

    initialization
    clone/copy identity
    candidate top receipt
    exact storage change
    reject/retry immutability by construction
    endpoint-size mismatch fail-closed

Only after A19 should the backend optional-layout/restart integration be opened.
