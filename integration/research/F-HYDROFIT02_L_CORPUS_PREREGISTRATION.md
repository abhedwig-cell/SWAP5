# F-HYDROFIT02 P-LCORP01 — BRO lambda corpus preregistration

Authority observed: `integration/f-ci-canonical@1113eb11966f3e5a5ced5c6e14f243d6de79a3b5`.

## Purpose

Characterize the empirical source-lambda distribution and the prevalence of hydrophysical records for the officially observed BRO delivery accountable party `27378529`.

This workunit is descriptive. It must not tune production lambda bounds.

## Population

Enumerate BHR-P IDs using the official `bro-ids` endpoint with delivery accountable party / KvK `27378529`.

For the first corpus pass:

- sort IDs lexically for deterministic ordering;
- inspect at most the first 100 objects to bound network load;
- retain only objects whose official object response contains survey purpose `bodemfysischOnderzoek`;
- among those, characterize only intervals containing `WaterContentAndConductivityAtSpecificSoilWaterPotential` and a `ShapeHydraulicConductivityCurve`.

If fewer than 20 qualifying intervals are found in the first 100 IDs, a later preregistered extension may inspect the next block.

## Metrics

Report:

- total IDs returned for the party;
- objects inspected;
- bodemfysischOnderzoek objects;
- qualifying hydrophysical intervals;
- source lambda min, median, max;
- quantiles 0.05, 0.25, 0.75, 0.95;
- counts lambda <0, =0, >0;
- count outside [-4,0];
- source modelling procedure/method frequencies;
- observation-count distribution.

## Gates

C0. No invented IDs.

C1. Raw object fetch failures are retained as counts.

C2. No source lambda is excluded because it is surprising.

C3. No production bound or prior is inferred from this first bounded corpus alone.

C4. If source-lambda values are multimodal or span both signs materially, report that rather than collapsing to one default.
