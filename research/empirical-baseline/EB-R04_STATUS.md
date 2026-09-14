# EB-R04 status — current-canonical B1.10 water balance

Status: **PASS**

## Scope

EB-R04 replays the historical F-MR04 physical fixture against the current canonical serialized B1.10 backend. The historical qualification is used only as an experimental oracle. It is not inherited as current qualification because the production backend has changed since F-MR04.

This slice observes one bounded uniform-head, balanced-forcing Richards case. It tests real HeadCalc execution, authoritative interval mass accounting, rollback isolation, checkpoint replay identity, and optimization-level determinism.

## Provenance

- Canonical empirical-baseline start: `d44b2eb48e7187f8ddc622a5f2329d7a24c24aa0`
- Tested empirical-baseline head: `8274bc336d3d3d51285a22775eceefadf2d7673a`
- Green workflow run: `34875125808`
- Historical oracle ref in CI: `origin/qualification/f-vq14-fmr04-physical-runtime`
- Historical fixture: `tests/fmr/test_fmr04_serialized_physical.F90`
- Historical fixture blob: `11981391d0a504a66473c0281bf51defa6d1eac8`
- Historical serialized backend blob: `ade399a1df4b582c9038442093ccacce034f923d`
- Current serialized backend: `src/runtime/mod_fmr_serialized_reference_backend.f90`
- Current serialized backend blob: `3506b453ba6a00111d182f29db8cbfb288001854`

The historical and current backend blobs differ. Therefore no current scientific claim is inherited solely from F-MR04; the historical fixture is re-executed against current production code.

## Current-canonical observation

The O0 and O2 outputs are byte-identical.

```text
case_id,t0,t1,storage_start,storage_end,storage_change,total_in,total_out,residual,top_flux,bottom_flux,iterations,accepted_transactions,candidate_fingerprint
b110_uniform_head_balanced_forcing,1000.125000000000,1000.625000000000, 1.03773468993800799E+000, 1.03773468993800799E+000, 0.00000000000000000E+000, 8.13696032106573097E-002, 8.13696032106573097E-002, 0.00000000000000000E+000,-1.62639206421314603E-001,-1.62639206421314603E-001,1,1,-3142087914492722297
```

Observation SHA-256:

`23e5cdfdeca0c759c9e4143e40989eae23ebe1f2b7eeddb08653b94d8da69e15`

Observed properties:

- the real solver executed through route `legacy-reference-bound`;
- storage start and end are identical at `1.03773468993800799`;
- authoritative storage change is exactly zero;
- authoritative inflow and outflow are identical at `8.13696032106573097E-002`;
- authoritative interval mass residual is exactly zero;
- observed top and bottom flux are identical at `-1.62639206421314603E-001`;
- one nonlinear iteration and one accepted transaction are recorded;
- discarding the first candidate leaves committed state and revision unchanged;
- replay from the same checkpoint reproduces the candidate fingerprint and authoritative mass fields exactly.

The gate emitted:

- `EB_R04_REAL_HEADCALC_EXECUTED=PASS`
- `EB_R04_AUTHORITATIVE_MASS_CLOSURE=PASS`
- `EB_R04_ROLLBACK_REPLAY_IDENTITY=PASS`
- `EB_R04_O0_O2_OBSERVATION_IDENTITY=PASS`
- `EB_R04_CURRENT_CANONICAL_B110_WATER_BALANCE_OBSERVATION PASS`

R01, R02, R03 and R04 all passed in workflow run `34875125808`.

## Failed-run classification during harness construction

Two red runs preceded the green evidence and are not model failures:

1. Run `34874751010` stopped before Fortran execution because the historical qualification branch was addressed as a local branch rather than its fetched remote-tracking ref. The harness was changed to use `origin/qualification/f-vq14-fmr04-physical-runtime`.
2. Run `34874955850` passed the R04 scientific assertions and failed only when formatting the observation row: the format descriptor declared seven scientific-real fields while eight were supplied. The only correction was the output-format arity from `7(...)` to `8(...)`; no physical fixture, production source, numerical assertion, tolerance, or expected result was changed.

## Claim boundary

EB-R04 supports only the bounded current-canonical case executed here. It does **not** by itself establish equivalence for all B1.10 configurations, transient nonlinear trajectories, alternative bottom-boundary modes, root uptake, snow, drainage families, or MultiSWAP composition.

The most direct remaining hydraulic gap is a current-canonical transient case with nonzero storage response, because EB-R04 deliberately exercises a balanced case with zero storage change.
