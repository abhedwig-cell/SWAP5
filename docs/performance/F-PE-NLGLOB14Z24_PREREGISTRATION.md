# F-PE-NLGLOB14Z24 preregistration — groundwater coupling-surface relevance of moving-interface chatter

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

Parent authority:

- Z22: repeated finite internal ownership chatter is real and transaction-clean;
- Z23: settled-event publication can coalesce the observed internal event bursts without changing the internal physical trajectory;
- Z23 also falsified simple committed-ownership dwell/confirmation.

## Purpose

Determine whether the Z19-Z23 moving-interface ownership events are actually part of the current external groundwater-coupling contract surface.

This is a contract-relevance audit.

It must prevent a production mechanism from being designed for an event channel that the admitted coupling architecture does not expose.

## Frozen authority set

Audit the current-canonical versions of:

- `src/adapter/mod_groundwater_external_gateway.f90`;
- `src/runtime/mod_groundwater_coupling_contract.f90`;
- `src/runtime/mod_groundwater_interface_mass_ledger.f90`;
- `docs/science/groundwater-coupling.md`;
- `docs/integration/F-GC41_WHOLE_WINDOW_ACCEPTANCE_RETRY.md`;
- `docs/integration/F-GC42_WHOLE_WINDOW_SERVICE_COMPOSITION.md`;
- `docs/integration/F-GC43_PRODUCTION_SWAP_PARTICIPANT.md`.

The relevant files are byte-identical between canonical and the Z24 research baseline at preregistration.

## Frozen questions

### Q1 — external gateway payload

Does the external groundwater backend contract expose any moving-interface ownership quantity such as:

- internal split face;
- saturated-tail index;
- upper/lower ownership identifier;
- ownership direction event;
- chatter/event notification?

### Q2 — scientific interface quantities

Does the admitted groundwater scientific boundary define exchange in terms of:

- hydraulic head; and
- whole-window water exchange / paired interface flux,

rather than internal split ownership?

### Q3 — mass/publication authority

Is the externally relevant accepted publication authority tied to:

- the accepted SWAP candidate;
- prepared groundwater state/timestep;
- the whole-window exchange ledger;
- accepted coupling-window identity,

rather than a stream of internal ownership-change notifications?

### Q4 — temporal mapping

Does current canonical authority explicitly establish that each fine TIMEINT17/NLGLOB research interval is one external groundwater coupling window?

Absence of such an explicit mapping must be recorded as `NOT_ESTABLISHED`; it may not be inferred.

## Frozen classifications

### INTERNAL_OWNERSHIP_NOT_EXTERNAL_SURFACE

Require all of:

- no external gateway callback/argument carries moving-interface ownership;
- coupling contract state exchanged with groundwater contains no moving-interface ownership field;
- mass ledger stages whole-window exchange, not ownership events;
- scientific documentation identifies head and water exchange as the interface quantities.

### INTERNAL_OWNERSHIP_EXPOSED

Classify if any current-canonical external coupling contract explicitly publishes or consumes moving-interface ownership.

### TIMEINT_TO_COUPLING_WINDOW_MAPPING_ESTABLISHED

Only if an owning canonical authority explicitly maps the NLGLOB fine research interval to one external coupling window.

### TIMEINT_TO_COUPLING_WINDOW_MAPPING_NOT_ESTABLISHED

If no such owning authority exists in the frozen authority set.

## Frozen aggregate interpretation

If internal ownership is not on the external surface and TIMEINT-to-coupling-window mapping is not established:

`QUALIFIED_Z24_CHATTER_INTERNAL_TO_SWAP_COUPLING_RELEVANCE_NOT_ESTABLISHED`.

If ownership is explicitly exposed:

`NLGLOB14Z24_OWNERSHIP_IS_EXTERNAL_COUPLING_SURFACE`.

If the temporal mapping is explicitly established while ownership remains internal:

`QUALIFIED_Z24_INTERNAL_OWNERSHIP_WITH_EXPLICIT_WINDOW_MAPPING`.

Any contradiction among code and owning documentation:

`NLGLOB14Z24_COUPLING_CONTRACT_INCONSISTENT`.

## Interpretation boundary

A result that ownership is internal does not prove chatter is free.

It would mean the immediate production concern is internal execution cost, diagnostics and state-management cleanliness rather than groundwater-coupling event publication.

It would also mean Z23 settled-event publication must not be promoted into the groundwater API without a separate reason.

## Stop rules

Do not:

- add a new coupling field;
- reinterpret SWAP internal ownership as groundwater interface state;
- assume one research fine interval equals one external coupling window;
- change production code;
- change accepted-state or mass semantics.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z24

BASELINE: `f2a024237d9ac191f3916ce38ea134dcb8bf8acb`

BRANCH: `research/f-pe-nlglob14z24-coupling-surface-relevance`

NEXT SAFE STEP: execute a static contract audit against the frozen canonical-equivalent source/document set.

## Production boundary

Research/audit only. No production source/default change.
