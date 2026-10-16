# F-PE-SETUP05 result — post-admission large-N setup reprofile

Date: 2026-09-27

Status: `CLOSED_NO_SECOND_SETUP_TARGET`

PR:
`#683 — F-PE-SETUP05: post-admission large-N setup reprofile`

Measured head:
`431168c3867a24951db15ecaf01a648556bde772`

Workflow run:
`36352701334`

## Results

### N=1,000

- app initialize: 0.004008 s;
- context materialization: 0.001447 s;
- origin capture: 0.000441 s;
- warm trial/tangent/discard: 0.038719 s;
- total setup through warm-up: 0.047593 s.

Dominant family:
`WARM`, share about 81.4%.

### N=10,000

- app initialize: 0.034281 s;
- context materialization: 0.013508 s;
- origin capture: 0.005257 s;
- warm trial/tangent/discard: 0.388607 s;
- total setup through warm-up: 0.466559 s.

Dominant family:
`WARM`, share about 83.3%.

### N=40,000

- config construction: 0.075756 s;
- app initialize: 0.128749 s;
- topology/predictor construction: 0.006828 s;
- context materialization: 0.049584 s;
- origin capture: 0.023015 s;
- warm trial/tangent/discard: 1.546808 s;
- total setup through warm-up: 1.844840 s.

Dominant family:
`WARM`, share about 83.8%.

## Interpretation

SETUP04 successfully removed the dominant large-N bootstrap pathology.

At N=40,000:
- pre-SETUP04 app initialize was roughly 3.59-4.68 s depending on measurement authority;
- post-SETUP04 app initialize is about 0.129 s.

The remaining dominant setup-through-warm-up cost is the first physical trial itself.

No non-physical setup family satisfies the frozen successor rule:
- >=25% of total setup;
- >=0.25 s absolute;
- not already-qualified physical trial work.

The largest remaining non-physical family, app initialize, is only about 7% of total setup-through-warm-up at N=40,000 and costs about 0.129 s.

## Decision

Close the large-N setup optimization line.

Do not open another setup workunit without new production lifecycle evidence showing that a non-physical setup component has again become material.

Recommended next independent performance direction:
compiler / code-generation qualification on the production-shaped repeated workload.

