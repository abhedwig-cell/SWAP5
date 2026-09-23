# RM04 transactional SWAP irrigation-state contract

## Evidence boundary

Legacy B1.10 process checkpoint authority persists `dayfix` and `nirri` when irrigation scheduling is active, and persists crop state including DVS. F-APP07 independently qualifies the typed Hupsel TCS1/DCS2 process for split/rollback/replay and A-B-A determinism. F-APP05 independently qualifies Rutter as a stateful process whose accepted state is canopy storage.

The current production FMR committed-state family does not yet compose those three continuation surfaces into the same accepted application transaction. This contract defines that missing ownership before implementation.

## Required accepted state

For the restricted Hupsel management route, the minimum accepted continuation is:

1. **typed irrigation continuation**
   - `dayfix`
   - `active_event`
   - `active_event_start`
   - `active_event_end`

2. **crop continuation sufficient to reproduce the request**
   - accepted crop owner state, including at minimum emergence/lifecycle and DVS
   - accepted transpiration/root-uptake information must enter through an accepted-window receipt or equivalent immutable input whose identity is bound to the same accepted origin

3. **Rutter continuation when SWINTER=3**
   - `canopy_storage_cm`

4. **transaction provenance**
   - committed lineage/revision/time
   - candidate origin lineage/revision and interval

These state classes must be checkpointed, cloned for trials, discarded on rejection and published only on commit.

## Legacy nirri disposition

`nirri` is classified by F-CI08 as legacy persistent irrigation process state. The current typed TCS1/DCS2 process does not carry it. Therefore:

- `nirri` is **not** silently dropped as irrelevant;
- `nirri` is **not** copied into the new typed state merely because it exists in legacy globals;
- production admission requires a source/equivalence check demonstrating either:
  1. its future-decision semantics are represented by the typed event state for the admitted Hupsel route, or
  2. an additional typed persistent field is required.

RM05 closes this gate for the first admitted typed Hupsel management route by ownership exclusion: the typed TCS1/DCS2 selector is the sole management-event owner and the legacy selector is disabled/bypassed for that decision. In that bounded route, `nirri` remains legacy-route state and is not duplicated into the typed state. The resulting classification is `LEGACY_ROUTE_STATE_NOT_APPLICABLE_TO_TYPED_OWNER`. This does not change the F-CI08 legacy classification.

## Explicit non-state

The following remain outside accepted scientific state unless a later source-bound proof says otherwise:

- `irrigevent`, `cirr`, `gird`, `nird`, `qssdi`, `qssdisum`, `dt_irr_event`;
- mutable forcing/event cursors whose value is derivable from accepted time and immutable schedule data;
- allocation shortage;
- Ribasim allocation output;
- worker numerical scratch;
- reporting/accounting cursors.

They may exist in trial-local or runtime-control context but may not alter future accepted SWAP physics after rollback.

## Retry determinism gate

For one committed origin O and immutable management inputs M:

`decision(O,M) == decision(rollback(trial(O,M)),M)`.

The equality includes:
- trigger/no-trigger classification;
- requested irrigation depth;
- event start/end;
- candidate dayfix;
- gross application rate;
- Rutter gross-to-net result when active.

A test must force at least one rejected trial between the two evaluations.

## Atomicity rule

Irrigation continuation, Rutter candidate state and the hydrological candidate consuming the same supplied water must be accepted as one outer transaction. A state commit without its corresponding water transfer, or a water transfer without its corresponding process-state commit, is forbidden.

## Restart rule

A restart record at an accepted boundary must reconstruct the accepted irrigation continuation, crop owner state, Rutter canopy storage and scheduling identity before a new demand is derived.

## Current decision

The legacy `nirri` equivalence gate is **closed for the bounded typed-owner route** by RM05.

RM06 has qualified the shared management transaction semantics for typed irrigation plus Rutter state, including reject/replay identity, exactly-once commit, restart persistence and explicit separation of requested, allocated, physically supplied and net-applied irrigation.

RM07 has qualified read-only demand derivation from an immutable accepted management origin. RM10 has additionally bound the Ribasim realization receipt to that exact SWAP management lineage/revision/crop-origin/interval and fails closed on cross-origin or partial-realization values outside the bounded RM09 envelope.

Therefore the management-state contract is now `QUALIFIED_FOR_BOUNDED_TYPED_MANAGEMENT_TRANSACTION`.

Remaining composition boundary: the management-state commit must still be qualified atomically with the real Richards hydrological candidate that consumes the same supplied irrigation water. That is the RM13 three-model composition workunit; it is not retroactively claimed by RM04.
