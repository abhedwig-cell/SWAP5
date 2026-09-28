# F-HYDROFIT02 P-LCORP02 — spatial candidate selection preregistration

Authority observed: `integration/f-ci-canonical@7b73f4545f79e3e3575ed21d9c94d3d5a21e3ea9`.

## Purpose

Select a bounded corpus of modelled BHR-P objects for accountable party `27378529` without conditioning discovery on lambda values.

## Grid

Use a deterministic coarse Netherlands grid:

- latitudes: 50.8, 51.0, ..., 53.4;
- longitudes: 3.5, 3.8, ..., 7.1;
- enclosing-circle radius: 10 km, the service maximum.

This is a coverage grid, not an assertion that every circle lies entirely within the Netherlands.

## Search criteria

Every query uses exactly:

- `area.enclosingCircle`;
- `deliveryAccountableParty = 27378529`;
- `characteristicModelled = JA`.

No lambda, soil type, fit quality or hydraulic value is used in discovery.

## Candidate handling

- deduplicate BRO IDs across overlapping circles;
- sort IDs lexically after discovery;
- inspect at most the first 200 unique candidates in this pass;
- retain only `bodemfysischOnderzoek` objects;
- characterize intervals only when both joint theta/K observations and `ShapeHydraulicConductivityCurve` are present.

## Gates

S0. Query errors are counted and retained.

S1. Any service result-limit rejection is reported; the affected circle is not silently treated as complete.

S2. Lambda values are read only after candidate selection is frozen.

S3. No production prior/bound is derived solely from this pass.
