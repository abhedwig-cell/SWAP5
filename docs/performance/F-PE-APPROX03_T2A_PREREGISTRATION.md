# F-PE-APPROX03 T2A preregistration — 2x temporal budget candidate

Date: 2026-09-26

Status: `PREREGISTERED_EXPERIMENT_ONLY`

Parent:
`F-PE-APPROX03 — practical timestep / temporal-effort frontier`

Predecessor:
`F-PE-APPROX03 T2 — prescribed-head temporal-budget frontier`

## Candidate

T2A changes only the production mode-5 model temporal-indicator head budget:

- reference: `1e-5 cm`;
- candidate: `2e-5 cm`.

All local Richards convergence tolerances, mass tolerance, retry policy, iteration caps, backtracking policy and constitutive physics remain unchanged.

A2C remains OFF during this qualification stage.

## Why 2x advances

The initial three-case production-consistent mode-5 frontier showed:

- runtime speedup about 19% to 31%;
- accepted-substep reduction from 10-14 to 7-10;
- large nonlinear and HeadCalc work reduction;
- relative pressure-head error below `9e-8`;
- relative water-content error below `2e-8`;
- storage-change deviation below about `0.7%`;
- terminal bottom-flux deviation below about `2.2%`;
- no retries;
- canonical mass residual at roundoff scale.

The 4x and 8x arms were faster but showed materially larger bottom-flux drift. In the initial frontier, 4x reached about 5.2% terminal bottom-flux error and 8x about 16.9%.

Therefore only 2x advances from T2.

## T2A material/regime matrix

The next gate broadens the candidate across:

- materials: B01, B12, O05, O14;
- initial regimes: wet `h0=-10 cm`, mid `h0=-75 cm`, dry `h0=-500 cm`;
- two forcing orientations.

The forcing magnitude is scaled to the local hydraulic conductivity rather than imposed as one absolute flux across all soils.

For each material/regime, define local hydrostatic initial conductivity at the top and bottom nodes, then use:

- orientation `plus`: top flux = `+5e-4 * K_top`, predictor qbot = `+5e-4 * K_bottom`;
- orientation `minus`: top flux = `-5e-4 * K_top`, predictor qbot = `-5e-4 * K_bottom`.

Requested interval:

`0.01 day`

The prescribed bottom-face head is materialized from the predictor qbot with the same B1.10 Darcy mapping used by the production FGC44 route.

This gives 24 paired reference/candidate cases.

## Required measurements

Per case and arm:

- replicated runtime;
- accepted substeps;
- retries;
- nonlinear iterations;
- HeadCalc calls;
- terminal pressure-head profile;
- terminal water-content profile;
- terminal bottom flux;
- storage end and storage change;
- canonical mass residual.

Report candidate minus reference error, not candidate values alone.

## Advancement rule

T2A can continue to application-shaped and coupled qualification only if:

1. all 24 reference and candidate arms commit;
2. no candidate-only retry or failure class appears;
3. work reduction is systematic rather than isolated;
4. pressure-head and water-content deviations remain small;
5. storage-change drift remains bounded;
6. no systematic sign-dependent bottom-flux bias appears;
7. unchanged canonical mass accounting remains satisfied.

No production opt-in is admitted by this preregistration.
