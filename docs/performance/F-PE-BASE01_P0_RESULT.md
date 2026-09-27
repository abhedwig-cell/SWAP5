# F-PE-BASE01 P0 result — current-canonical participant/backend boundary

Date: 2026-09-27

Status: `PASS_BACKEND_INTERNAL_DECOMPOSITION_JUSTIFIED`

PR:
`#660 — F-PE-BASE01: base q/state Richards solve decomposition`

Current-head authority:
- branch head exercised: `c5f1881d3d95695993ab6420e232adb32c9df60b`;
- workflow run: `36306634228`;
- job: `p0-participant-boundary`.

## Scope

P0 remeasures the exact participant/backend boundary on current canonical authority after TEMPORAL08 and LIVE01.

The frozen 12-group difficult live population is retained.

The effective temporal budget is:

`max(1e-5 cm, 0.65 * dt * ||h_dot_previous||inf)`.

No production source is modified.

## Aggregate result

Across 32 exact participant trials represented by the 12 group medians:

- total exact SWAP trial time: `1,881,594 ns`;
- forcing materialization: `29,693 ns`;
- serialized Reference backend: `1,520,452 ns`;
- participant postprocessing/response construction: `324,858 ns`.

Shares:

- forcing: `1.5781%`;
- serialized backend: `80.8066%`;
- participant postprocessing: `17.2650%`.

The small nonclosure of the timing buckets against total trial time is instrumentation/timer boundary overhead and is not interpreted as a separate physical cost family.

## Gate disposition

Preregistered P0 advancement gate:

`serialized backend share >= 60%`.

Observed aggregate:

`80.8066%`.

Decision:

`ADVANCE_BACKEND_INTERNAL_DECOMPOSITION`.

Forcing materialization is too small to justify a separate optimization line.

Participant postprocessing remains measurable but is secondary to the backend and is not selected as the primary target.

## Interpretation

LIVE01 selected the base q/state Reference Richards solve after:

- directional work missed its 20% primary-successor gate;
- widening the temporal floor removed no live retry and yielded no runtime benefit.

P0 localizes that base q/state target further: the dominant cost remains inside the serialized Reference backend, not in forcing materialization or outer participant handling.

The exact timing percentages vary across CI runs, but the P0 decision is stable and remains far above the frozen 60% gate.

## Next phase

P1 decomposes the current backend path into nonlinear/HeadCalc work and the remaining outer backend control path.

No optimization is admitted by P0.
