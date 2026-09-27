# F-PE-BASE01 P0 result — current-canonical participant/backend boundary

Date: 2026-09-27

Status: `PASS_BACKEND_INTERNAL_DECOMPOSITION_JUSTIFIED`

PR:
`#660 — F-PE-BASE01: base q/state Richards solve decomposition`

Authority:
- branch head exercised: `1bf8f50786fbf73b09726f2163e80c095d5b732a`;
- workflow run: `36304378483`;
- job: `p0-participant-boundary`.

## Scope

P0 remeasures the exact participant/backend boundary on current canonical authority after TEMPORAL08 and LIVE01.

The frozen 12-group difficult live population is retained.

The effective temporal budget is:

`max(1e-5 cm, 0.65 * dt * ||h_dot_previous||inf)`.

No production source is modified.

## Aggregate result

Across 32 exact participant trials represented by the 12 group medians:

- total exact SWAP trial time: `1,894,357 ns`;
- forcing materialization: `32,100 ns`;
- serialized Reference backend: `1,578,403 ns`;
- participant postprocessing/response construction: `279,557 ns`.

Shares:

- forcing: `1.6945%`;
- serialized backend: `83.3213%`;
- participant postprocessing: `14.7574%`.

The small nonclosure of the three timing buckets against total trial time is timer/instrumentation boundary overhead and is not interpreted as a separate physical cost family.

## Group range

Backend share is material in every frozen live group:

- minimum observed: approximately `77.7%`;
- maximum observed: approximately `86.7%`.

Wet B01/O05 groups are near the upper end because the admitted live trajectory contains temporal retry/substep work.

## Gate disposition

Preregistered P0 advancement gate:

`serialized backend share >= 60%`.

Observed aggregate:

`83.3213%`.

Decision:

`ADVANCE_BACKEND_INTERNAL_DECOMPOSITION`.

Forcing materialization is too small to justify a separate optimization line.

Participant postprocessing remains measurable but is secondary to the backend and is not selected as the primary target.

## Interpretation

LIVE01 selected the base q/state Reference Richards solve after:

- directional work missed its 20% primary-successor gate;
- widening the temporal floor removed no live retry and yielded no speed benefit.

P0 now localizes that base q/state target further: the dominant cost is inside the serialized Reference backend, not in forcing materialization or outer participant handling.

## Next phase

P1 must decompose the current backend path into:

- transaction/substep control;
- nonlinear iteration/control;
- constitutive evaluation;
- residual/Jacobian work;
- tridiagonal factorization/solve;
- backtracking candidate evaluation;
- accepted-state/candidate materialization;
- residual backend overhead.

No optimization is admitted by P0.
