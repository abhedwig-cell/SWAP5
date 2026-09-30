# F-PE-NLGLOB14Z44 preregistration — heterogeneous reference-validity fixture selection

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Parent authority:

- Z43: `Z43_HOLDOUT_PHYSICAL_FAILURE`;
- Z43 O05 passes;
- frozen O14 full-reference trajectory fails before adaptive comparison;
- Z43 default-off configuration seam passes.

## Purpose

Select reference-valid N=64 trajectory fixtures for O14 and B12 before any renewed moving-interface admission comparison.

Z44 is strictly reference-only.

No adaptive manager route is executed in this workunit.

## Frozen full-reference candidate matrix

Materials:

- O14;
- B12.

For each material evaluate candidates in this exact priority order:

1. tail start 49, dt = 0.00125 d;
2. tail start 45, dt = 0.00125 d;
3. tail start 41, dt = 0.00125 d;
4. tail start 37, dt = 0.00125 d;
5. tail start 49, dt = 0.000625 d;
6. tail start 45, dt = 0.000625 d;
7. tail start 41, dt = 0.000625 d;
8. tail start 37, dt = 0.000625 d.

Common:

- N = 64;
- dz = 10 cm;
- initial hydrostatic qbot=0 lower tail;
- initial head: `h_i = 10*(i-tail_start) cm`;
- fixed top flux = -0.01 cm/d;
- qbot = 0;
- zero sources/sinks;
- 4,000 nominal intervals;
- actual compiled Heritage/reference HeadCalc service;
- no retries to another fixture inside a single candidate.

## Frozen candidate-validity gates

A candidate is reference-valid only if all 4,000 intervals:

- converge;
- remain finite;
- retain contiguous lower saturated-tail geometry;
- ownership moves at most one face per interval;
- absolute per-interval physical ledger <= 5e-8 cm;
- provider/top route remains valid;
- no accepted-origin mutation occurs.

## Frozen deterministic fixture-selection rule

For each material:

- evaluate all eight candidates;
- select the **lowest-numbered valid candidate**;
- later candidates may not replace an earlier valid candidate based on timing or convenience;
- if no candidate is valid, classify that material as reference-fixture unavailable.

Timing is not used for selection.

## Frozen classifications

### `QUALIFIED_Z44_REFERENCE_FIXTURES_SELECTED`

Require at least one valid candidate for both O14 and B12.

### `Z44_O14_REFERENCE_FIXTURE_UNAVAILABLE`

No O14 candidate passes.

### `Z44_B12_REFERENCE_FIXTURE_UNAVAILABLE`

No B12 candidate passes.

### `Z44_REFERENCE_FIXTURES_UNAVAILABLE`

Neither material has a valid candidate.

### `Z44_REFERENCE_SELECTION_EXECUTION_INVALID`

Build/timer/parser invalid.

## Consequence

If both fixtures are selected, persist their exact material / tail-start / dt definitions.

A separate successor may then run adaptive-manager comparisons on:

- O05 Z43 authority;
- selected O14 fixture;
- selected B12 fixture.

Do not perform adaptive comparison inside Z44.

## Stop rules

Do not:

- change candidate order after exposure;
- choose a later valid candidate for better performance;
- tune forcing;
- add manager logic;
- reinterpret a failed full-reference candidate as manager evidence.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z44

BASELINE: `de3473d2b36dba478c8d299853279ccbf466aead`

BRANCH: `research/f-pe-nlglob14z44-reference-fixture-selection`

NEXT SAFE STEP: execute one compact compiled reference-only matrix and persist deterministic selected fixtures.

## Production boundary

Reference fixture preparation only.

`LEGACY_NUMERICS` remains production default.
