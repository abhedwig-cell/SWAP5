# F-PE-MIQUAL08 preregistration — serialized dynamic reference-workload acquisition

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_RESULT`

Canonical authority:

`integration/f-ci-canonical@412592b874111f35404171f223d3f2518bcad32e`

Parent authority:

- MIQUAL07: `MIQUAL07_DYNAMIC_REFERENCE_BLOCKED`;
- MIQUAL06: `QUALIFIED_MIQUAL06_SERIALIZED_RUNTIME_SEAM`.

## Purpose

Identify an existing repository-backed dynamic serialized-reference workload that can serve as unbiased LEGACY authority for a future manager performance benchmark.

No new forcing/tolerance combination may be invented by trial-and-error in this workunit.

## Frozen acquisition criteria

A candidate workload is admissible only if it already exists in repository tests and:

- executes through the serialized-reference runtime;
- uses the Reference Richards route rather than RossFast;
- has nontrivial physical evolution;
- already completes its own qualification gate;
- can be reconciled with the MIQUAL06 moving-interface execution envelope without changing the candidate's scientific meaning.

Reject candidates requiring any of:

- RossFast;
- active macropore;
- active root extraction;
- active snow or soil temperature;
- fixed-weir surface water;
- dynamic evaporation optional state;
- drainage-response coupling;
- active accepted-trajectory side service;
- unsupported bottom-boundary semantics.

## Search scope

Inspect at minimum all repository tests whose path or implementation uses the serialized-reference runtime, including:

- FMR serialized tests;
- FKT serialized trajectory tests;
- ROSS serialized production wiring;
- relevant serialized end-to-end tests.

## Frozen classifications

- `QUALIFIED_MIQUAL08_EXISTING_DYNAMIC_REFERENCE_FOUND`
- `MIQUAL08_NO_EXISTING_DYNAMIC_ELIGIBLE_REFERENCE`
- `MIQUAL08_EXECUTION_INVALID`

## Positive consequence

If an existing eligible workload is found, freeze it unchanged for a successor paired LEGACY/MANAGER benchmark.

If none exists, do not manufacture a new benchmark workload in this workunit. Open a targeted manager-envelope extension only against an already qualified repository reference case.

## Production boundary

No runtime or production-default change.
