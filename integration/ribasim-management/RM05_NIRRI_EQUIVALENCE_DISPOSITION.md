# RM05 nirri equivalence disposition

## Decision

For the first admitted real SWAP–Ribasim management profile, `nirri` is **not an independent continuation variable** when the typed scheduled-irrigation process is the authority for management-event selection and continuation.

This is a deliberately bounded equivalence decision. It does not erase the F-CI08 finding that legacy `MOD_irrigation%nirri` is persistent process state on the B1.10 legacy route. It says that the new typed route must not run the legacy selector in parallel. In that restricted route, the future irrigation decision is carried by the typed state and immutable schedule/configuration, so copying the legacy selector counter into the typed state would create two owners for one decision.

## Source-bound basis

F-CI08 classifies `dayfix` and `nirri` as optional persistent legacy irrigation process state, while `irrigevent`, `cirr`, `gird`, `nird`, `qssdi`, `qssdisum` and `dt_irr_event` remain trial workspace or derived values.

The current typed `mod_irrigation_process` exposes the continuation that actually controls its future event path:

* fixed scheduling: `next_fixed_event_index` plus active-event identity and interval;
* scheduled TCS/DCS management: active-event identity and interval, while a new decision is derived from accepted DVS, the accepted hydraulic view, immutable TCS/DCS tables and explicit boundary flags;
* no typed code path reads or mutates legacy `nirri`.

Therefore the safe production rule is ownership exclusion, not field mirroring.

## Admitted restricted profile

The first management-coupling fixture SHALL:

1. select the typed irrigation process as the sole irrigation-decision owner;
2. disable/bypass the legacy irrigation selector for the coupled decision;
3. derive a Ribasim request from the typed scheduled decision before physical application;
4. preserve `irrigation_state_t`, accepted crop/DVS input identity and the accepted hydraulic-view origin across retry;
5. commit the typed irrigation candidate only atomically with the accepted physical supply and SWAP hydrological candidate.

Under those conditions `nirri` is classified `LEGACY_ROUTE_STATE_NOT_APPLICABLE_TO_TYPED_OWNER`.

## Required gate

The retry test must evaluate one committed origin twice with an intentionally rejected trial between evaluations and prove equality of trigger classification, requested depth, event interval and candidate typed state.

A separate ownership assertion must fail the fixture if both the legacy irrigation selector and typed management selector are enabled for the same coupled request.

## Nonclaims

This disposition does not prove `nirri` irrelevant to legacy B1.10 execution, fixed legacy irrigation files, every SWAP irrigation option, or mixed legacy/typed operation. Those remain outside the first real SWAP–Ribasim admission envelope.
