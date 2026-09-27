# F-PE-SETUP01 P0 result — large-N groundwater setup decomposition

Date: 2026-09-27

Status: `P0_ONE_TIME_BOOTSTRAP_DOMINATES`

PR:
`#677 — F-PE-SETUP01: large-N groundwater setup decomposition`

Measured head:
`bcff0601cd6cb1d8c066b12c37271c3cefd62a85`

Workflow run:
`36350350145`

## Phase decomposition

### N=1,000

- config construction: 0.002313 s;
- `app%initialize`: 0.005694 s;
- pre-context/topology: 0.000167 s;
- context materialization: 0.001403 s;
- total through context: 0.009579 s;
- `app%initialize` share: 59.4%;
- context materialization share: 14.6%;
- first capture: 0.000422 s;
- first warm trial/tangent/discard: 0.038711 s.

### N=10,000

- config construction: 0.015752 s;
- `app%initialize`: 0.189127 s;
- pre-context/topology: 0.001388 s;
- context materialization: 0.010046 s;
- total through context: 0.216980 s;
- `app%initialize` share: 87.2%;
- context materialization share: 4.6%;
- first capture: 0.005391 s;
- first warm trial/tangent/discard: 0.291329 s.

### N=40,000

- config construction: 0.076542 s;
- `app%initialize`: 4.707355 s;
- pre-context/topology: 0.006731 s;
- context materialization: 0.050739 s;
- total through context: 4.842212 s;
- `app%initialize` share: 97.2%;
- context materialization share: 1.0%;
- first capture: 0.021411 s;
- first warm trial/tangent/discard: 1.605247 s.

## Interpretation

The recurring groundwater context-materialization step is not the large-N bottleneck.

At N=40,000 it costs about 0.051 s and only about 1% of setup through context materialization.

The dominant N-dependent cost is the one-time production application bootstrap `app%initialize(config)`.

Code inspection identifies two exact duplicate-detection loops inside `production_application_initialize`:

```fortran
if (i > 1) then
  if (any(config%tiles(1:i-1)%tile_id == config%tiles(i)%tile_id)) return
end if
```

and, for groundwater profiles:

```fortran
if (i > 1) then
  if (any(config%tiles(1:i-1)%ledger_id == config%tiles(i)%ledger_id)) return
end if
```

Both perform a growing prefix scan for every tile and therefore have O(N^2) comparison work in the no-duplicate production case.

This mechanism is consistent with the observed strongly superlinear growth of `app%initialize`.

## Decision

Do not open a recurring context-materialization optimization.

Advance instead:

`F-PE-SETUP02 — scalable tile/ledger identity uniqueness validation`

SETUP02 must preserve:
- exact acceptance/rejection semantics for unique and duplicate IDs;
- deterministic behavior;
- fail-closed handling;
- no change to any physical or coupling semantics.

The initial candidate should replace the two O(N^2) prefix scans with deterministic O(N log N) uniqueness checking on copied int64 identity arrays.

