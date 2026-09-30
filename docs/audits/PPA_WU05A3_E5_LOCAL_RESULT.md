# PPA-WU05-A3 E5 local rapid-drain result

Date: 2026-09-30

Status: `LOCAL_RESEARCH_PASS / RAPID_DRAIN_OWNERSHIP_SUPPORTED / NOT_YET_QUALIFIED`

## Source authority

Exact B1.11 `RAPIDDRAIN`, `macrorate.f90:1847-1933`.

The local reduction preserves the source relations for:

- crack width from `VlMpDmCp`;
- transmissivity-like `KDCrRl`;
- resistance scaling;
- positive-only hydraulic head difference;
- drainable-storage cap.

## Research question

Is rapid drainage an abrupt legacy switch with potentially discontinuous onset, or does the source formulation itself activate continuously once water level exceeds the drain/base elevation?

## Local one-compartment screen

Fixed source-consistent geometry was used while macropore water level was swept through the drain elevation `Z_DraBas=-80 cm`.

Observed rapid-drain rates:

- `Z=-90`: 0;
- `Z=-81`: 0;
- `Z=-80`: 0;
- `Z=-79.9`: `0.005 cm d-1`;
- `Z=-79`: `0.05 cm d-1`;
- `Z=-75`: `0.25 cm d-1`;
- `Z=-60`: `1.0 cm d-1`.

Immediately above onset, response is linear in the positive hydraulic head difference while resistance is unchanged.

A separate high-head case with only `0.03 cm` drainable water was capped exactly at `0.03 cm` outflow over the step.

## Interpretation

At fixed geometry/resistance, B1.11 rapid drainage has a continuous zero-to-positive onset at the drain/base elevation. The later storage cap prevents the process from removing more water than is drainable.

This supports A1 mass ownership:

- `QRapDra` is a genuine external outflow;
- it should be booked exactly once;
- it must be discarded on rejected trials;
- it is not part of matrix/macropore internal-exchange cancellation.

## What is not yet tested

- multi-compartment kD weighting;
- changing crack geometry within the same accepted step;
- drain-tube versus open-drain topology;
- interaction with groundwater and ponding;
- coupled timestep response.

## Next step

E6 shall adjudicate the undefined `icgwl` saturated/unsaturated partition index using source geometry and controlled storage profiles before any corrected reference implementation is selected.
