# F-PE-DYNTOP-PREDICT03 result — blind H0 classifier validation

Date: 2026-09-28

Status: `CHEAP_DYNAMIC_TOP_CLASSIFIER_VALIDATED_RESEARCH_ONLY`

Authority:

- canonical authority reconciled through `integration/f-ci-canonical@79dde9d93fe17dd686ba9902eca2bd0ab0d2f26b`;
- DYNERR01/DYNERR01A authority is incorporated in branch history;
- TIMEARCH01 authority is incorporated in branch history;
- Actions run: `36419185468`;
- blind-validation job: `108917514051`;
- conclusion: SUCCESS.

## Frozen H0 rule

A proposed large interval is classified SAFE only when:

1. two accepted history intervals are available;
2. the corrected origin-frozen dynamic-top predictor is available;
3. origin-frozen runoff potential is false;
4. the most recent normalized accepted head movement satisfies:

`r_last <= 0.10`

with

`r_last = max_i(|h_i(t_k)-h_i(t_{k-1})| / max(10 cm, |h_i(t_{k-1})|))`.

No material or regime identifier participates.

## Blind validation

Validation used 16 new source cases across all four hydraulic archetypes and four new forcing/state regimes.

Produced large-step labels:

- total: 24;
- locally SAFE: 21;
- locally UNSAFE: 3;
- hydraulic archetypes contributing labels: 4/4;
- WET/POND labels: 7;
- incomplete source cases: 1.

Classifier result:

- true safe: 11;
- false safe: 0;
- true unsafe: 3;
- false unsafe: 10;
- safe coverage: 52.4%.

Frozen validation requirements:

- at least 10 labels: PASS;
- zero false safe: PASS;
- safe coverage >=50%: PASS;
- at least 3 materials represented: PASS, 4;
- at least one WET/POND label: PASS, 7.

## Interpretation

H0 replicated its calibration behavior on an unexposed bank.

It is deliberately conservative, rejecting about half of locally safe large intervals, but it did not release any locally unsafe interval in either calibration or blind validation.

Combined evidence:

- calibration: 31 labels, 10 unsafe, 0 false safe, 57.1% safe coverage;
- blind validation: 24 labels, 3 unsafe, 0 false safe, 52.4% safe coverage.

This is materially stronger than:

- surface-only PREDICT01, which produced 4 false-safe intervals;
- dynamic-top defect DYNERR01, which was not sufficiently predictive and had a severe regime-transition false-safe.

## Decision

H0 is validated as a research-only cheap classifier of candidate large intervals.

It receives no production timestep authority in PREDICT03.

The valid integration point is the explicit shadow-controller/proposal seam from the TIMEARCH redesign, not direct mutation of legacy TimeControl.
