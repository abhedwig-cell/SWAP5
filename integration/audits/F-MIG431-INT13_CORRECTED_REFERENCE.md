# F-MIG431-INT13 Rutter reference decision

## Authority and Git source search

The controlling historical identity remains SWAP 4.3.1/B1.11: corrected
`MOD_meteo.f90` SHA-256
`99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f`,
`swap.f90` SHA-256
`39d1cbd93dbd0f99505e92ef94ac0d23bddb496529c280397d2d7c2b7eb9b58a`, and
the 63-member manifest SHA-256
`24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2`.

The public Git repository `SWAP-model/SWAP` is present, but its repository
description, sole `v4.2.0` tag and 4.2.0 source history identify it as SWAP
4.2.0, not B1.11. Its source was not promoted to the B1.11 equation oracle.
The exact B0 archive and reconstructed B1.11 source member are still not
materialized in this checkout. The B1.11 patch chain records that its only
`MOD_meteo.f90` correction is the bounded dynamic-crop meteo-loading scan
(SWAP-006); it does not edit the Rutter routine. The admitted F-APP05 process
and independent F-VQ114 algebra qualification remain the executable Rutter
equation authority for the bounded Hupsel route.

## Legacy and corrected semantics

`LEGACY_B1_11` is the admitted short-interval process contract in
`mod_rutter_interception_process`: rates are selected from gross rain,
intercepted irrigation, canopy cover, canopy storage/capacity and wet-canopy
evaporation. The routine reports the time of a fill/empty event and returns a
candidate canopy store. This contract is conservative when its caller ends
the interval at that event and reevaluates the remainder from the new store.
It does not itself guarantee conservation for a longer call: the candidate
store is clipped to capacity while the interval throughfall rate was computed
before the event.

The falsifying case is an empty canopy, 100% cover, capacity `0.1 cm`, rain
`1 cm/day`, zero wet-canopy evaporation and a one-day interval. A direct legacy
call returns zero throughfall and `0.1 cm` final storage. The remaining
`0.9 cm` has no owner. Event-splitting the same interval returns `0.9 cm`
throughfall and `0.1 cm` storage, closing the balance to roundoff.

`CORRECTED_RUTTER_REFERENCE` applies the same legacy flux branches on
piecewise-constant forcing segments, ending each segment at the process's own
fill/empty event and integrating each returned rate over that segment. It
aggregates the interval-average throughfall, irrigation, evaporation,
wet-canopy fraction and crop/root transpiration. A decrease in canopy capacity
is treated as an instantaneous canopy-to-surface overflow; no water is clipped
away. The old interval API and its admitted F-APP05/Hupsel behavior are
unchanged.

This corrects an API/event-ownership limitation; it does not assert that the
historical full SWAP application failed to honor its event bound. The exact
B1.11 full call-site body remains unavailable for that stronger claim.

## SWAP5 processor and ownership

`mod_rutter_event_integrator` owns the fill/empty substepping inside one
constant-forcing interval. `mod_rutter_source_window_processor` composes that
physics with the admitted INT12 immutable source window and accepted progress.
One candidate contains both canopy storage and source-window progress.
`mod_fmr_rutter_source_window_application` maps the same candidate result to
the admitted dynamic-top precipitation/irrigation binding and crop/root PET
binding. It returns an uncommitted trial. The enclosing hydrological
transaction must call `accept_rutter_source_trial` only after its hydraulic
candidate is accepted; a rejected trial leaves both accepted Rutter fields
unchanged. Restart export/restore carries canopy storage and INT12 progress in
one record.

The integrator assumes piecewise-constant forcing within each immutable source
window. Detailed meteorology therefore uses one source window per meteo record;
canopy cover/capacity, PET and irrigation schedule changes must be represented
as window/segment boundaries. This is not a Richards substep policy.

## Qualification and claim ceiling

Local strict GNU Fortran O0/O2 evidence is recorded in
`F-MIG431-INT13_LOCAL_QUALIFICATION.json`. It covers capacity fill and
overflow, heavy rain with evaporation, rain-stop drying, capacity reduction,
source-window partition/refinement, rejected/changed-endpoint trials,
restart continuation, detailed-record continuation, application binding,
and output identity. The original admitted F-APP05 Rutter unit/Hupsel
observations also pass O0/O2, and the existing Rutter process blob remains
byte-identical.

This branch does not yet claim canonical admission. The Rutter source-window
processor/application seam is now implemented and locally qualified, but it
has not been attached to the owning production application bootstrap and its
hydraulic transaction commit/restart bundle. The following remain outside the
qualified envelope until an explicit fail-closed combination census and
preservation run exists: detailed-meteorology parser ownership, irrigation
event scheduling, Snow, Black/Boesten evaporation reduction, macropore top
input, and surface-water/Ribasim routes. The admitted SWINTER=0/1/2 and
F-APP05/F-APP08 claims are not changed.

The production attachment point is concrete: FMR's bootstrap constructs one
of the explicitly registered physical state families, and F-KT clones and
commits that dynamic type; restart admission separately checks the matching
template/state layout. A canopy-bearing Rutter family must therefore be added
as an owned physical continuation state and carried through clone, bootstrap,
forcing preparation, accepted publication and restart validation together.
The current source-window seam intentionally has no shortcut that mutates
kernel or solver scratch. Until those owners are composed, Richards retries
have only been falsified through the standalone source-window candidate API,
not through a real production hydraulic rejection.

## Production transaction composition required next

The production trace shows that `production_application_run_standalone_with_forcing`
passes a read-only forcing array to `fmr_run_serialized_physical_multiswap`.
Within that runtime, `execute_resolved_column` captures the accepted kernel
checkpoint, calls the backend trial, validates the whole result and mass record,
and commits the hydraulic candidate before returning the per-column result.
The bootstrap checks for completed/committed results only after dispatch, and
different columns can already have committed independently by then. Therefore
accepting an external Rutter registry after that return would create a split
commit if a later column failed; it is not a valid coupling strategy.

The next implementation must place Rutter in the per-column transaction owner:

1. Add an explicitly discriminated Rutter physical continuation state carrying
   canopy storage and accepted source-window progress; preserve its exact type
   in kernel clone/candidate operations and register its restart layout.
2. Prepare a Rutter trial from the same accepted snapshot and immutable forcing
   window before solver execution; use its throughfall/net irrigation (and the
   qualified crop/root flux mapping where applicable) as effective forcing.
3. Carry the unaccepted Rutter candidate through the backend trial and publish
   it only with that column's successful kernel candidate commit. Every retry
   starts from the accepted checkpoint, and a failed commit discards both.
4. Add production-host tests for retry-pattern identity, rejected trial state,
   mixed per-column acceptance behavior, and restart continuation, then
   fail-closed the unsupported application combinations.

This is a real cross-cutting state-family/application integration, rather than
a small adapter after the current bootstrap call. Until that owner is in place,
the present branch remains the locally qualified process/source-window seam.
