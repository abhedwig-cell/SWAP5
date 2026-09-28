# F-HYDROFIT02 — BRO acquisition result

Status: REAL-DATA ACQUISITION QUALIFIED  
Latest canonical observed during closeout: `integration/f-ci-canonical@50ee9dc2acbc9847807d3fd98d0553f9862d428b`

## Result

The official public BRO BHR-P service was accessed reproducibly from GitHub Actions. Its current service root exposes OpenAPI and the following operations:

- `GET /sr/bhrp/v2/bro-ids`;
- `POST /sr/bhrp/v2/characteristics/searches`;
- `GET /sr/bhrp/v2/objects/{broId}`.

Raw responses are preserved as CI artifacts with retrieval metadata and SHA-256.

## Discovery

A query within 10 km of Wageningen with `characteristicModelled=JA` returned three real BHR-P objects:

- `BHR000000346010`;
- `BHR000000346024`;
- `BHR000000378560`.

All three list delivery accountable party `27378529`.

Object `BHR000000378560` is explicitly classified with survey purpose `bodemfysischOnderzoek` and was selected as the first real-data parser case. Its fieldwork provenance is historical (1979-05) while registration occurred later; no claim is made here that it belongs to the Staringreeks 2018 new-sample subset.

## Raw object

`BHR000000378560` was retrieved successfully from the official object endpoint.

The response is approximately 54.7 kB XML and contains nine investigated intervals. Three intervals contain full hydrophysical determination/model records.

Observed structures include:

- saturated hydraulic conductivity determinations;
- stepwise water-retention determinations;
- water content and conductivity under decreasing soil-water potential;
- hydrophysical-characteristics modelling;
- Mualem-Van Genuchten model designation;
- fitted retention/conductivity shape arrays.

The BRO modelling procedure is `WENRHydrofysicav1`.

## Direct measured/derived hydraulic tuples

The SWE DataArray element type `WaterContentAndConductivityAtSpecificSoilWaterPotential` encodes triplets directly as:

`soil-water-potential, volumetric-water-content, hydraulic-conductivity`.

For the first interval, for example, the official object includes tuples spanning approximately:

- h = -15849 to 0 in the BRO source units represented by this element type;
- theta = 0.249 to 0.691;
- K = 2e-6 to 18.41 cm/d.

No interpolation was required to join theta and K.

## Normalized HYDROFIT export

The research exporter produced:

- 51 hydraulic observation triplets;
- 3 depth intervals;
- 3 associated model records.

Example normalized rows for the first interval (0.04-0.14 m):

`-15849, 0.249, 2e-6`
`-10000, 0.270, 5e-6`
`-7943, 0.280, 6e-6`
`-5623, 0.299, 1.1e-5`
`-3162, 0.328, 2.7e-5`

The raw object remains authority; normalized CSV is a derived research artifact.

## Parser correction retained

An initial parser looked for SWE field names and found zero hydraulic arrays. Inspection showed BRO represents these arrays by `elementType name` plus external schema href, not embedded field declarations. The parser was corrected to bind semantics through the element type. The negative result is retained conceptually because it prevents relying on an incorrect generic SWE assumption.

## Remaining provenance question

The real-data acquisition pipeline is solved.

What is not yet solved is the narrower historical question: which BRO objects correspond exactly to the 167 new samples used for Staringreeks 2018, and which older registered objects map to Priapus/Staringreeks source samples.

That mapping is a separate provenance task and does not block real-data HYDROFIT validation.

## Next gate

Use one of the three extracted intervals from `BHR000000378560` as the first real HYDROFIT fit case. Before fitting, bind the source element's soil-water-potential unit/sign semantics from the official BRO schema/catalogue and compare the new fit against the model parameters already stored in the same BRO object.

No solver-side performance claim is carried forward automatically because canonical SWAP authority changed during this acquisition workunit.
