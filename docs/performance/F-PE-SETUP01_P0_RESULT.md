# F-PE-SETUP01 P0 result — large-N production application-context setup decomposition

Date: 2026-09-27

Status: `P0_APP_INITIALIZE_DOMINATES_LARGE_N_SETUP`

PR:
`#676 — F-PE-SETUP01: large-N production application-context setup decomposition`

Measured head:
`31eeeb5dc79dbffcffd46f6e7ba3c17f1329b8d9`

Workflow run:
`36350308164`

## Results

### N=1,000

- library load: 0.001001 s;
- outer init call: 0.010418 s;
- config construction: 0.002363 s;
- app initialize: 0.005954 s;
- topology/predictor construction: 0.000164 s;
- context materialization: 0.001449 s;
- origin capture: 0.000487 s;
- first warm trial/tangent/discard: 0.038852 s;
- total setup through warm-up: 0.049757 s.

Dominant family:
`WARM`, share about 78.1%.

### N=10,000

- library load: 0.000853 s;
- outer init call: 0.219772 s;
- config construction: 0.015612 s;
- app initialize: 0.188662 s;
- topology/predictor construction: 0.001337 s;
- context materialization: 0.010543 s;
- origin capture: 0.005241 s;
- first warm trial/tangent/discard: 0.289432 s;
- total setup through warm-up: 0.514445 s.

Dominant family:
`WARM`, share about 56.3%.

### N=40,000

- library load: 0.001031 s;
- outer init call: 4.823461 s;
- config construction: 0.076797 s;
- app initialize: 4.675907 s;
- topology/predictor construction: 0.006824 s;
- context materialization: 0.051710 s;
- origin capture: 0.022684 s;
- first warm trial/tangent/discard: 1.559916 s;
- total setup through warm-up: 6.406060 s.

Dominant family:
`APP_INIT`, share about 73.0%.

## Scaling interpretation

`app%initialize` grows from:
- about 0.00595 s at N=1,000;
- to 0.18866 s at N=10,000;
- to 4.67591 s at N=40,000.

That growth is strongly superlinear.

Warm-up also grows materially, but much closer to the expected repeated physical-work scaling and no longer dominates large-N setup.

The selected immediate target is therefore the production bootstrap initialization path rather than context materialization, topology construction or origin capture.

## Code localization

Inspection of `production_application_initialize` identifies two cumulative uniqueness checks:

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

These checks are O(N^2) in population size.

At N=40,000 they imply on the order of hundreds of millions of integer comparisons and are consistent with the observed superlinear bootstrap cost.

This is a causal candidate, not yet a proven attribution.

## Decision

Advance:

`F-PE-SETUP02 — linear uniqueness-validation qualification`

The successor must preserve duplicate-ID rejection semantics exactly while replacing the cumulative prefix scans with a bounded linear or O(N log N) validation mechanism.

No production admission is authorized by SETUP01.

