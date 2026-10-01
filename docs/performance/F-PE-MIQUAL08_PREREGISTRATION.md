# F-PE-MIQUAL08 preregistration — serialized dynamic reference-workload acquisition

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_RESULT_CLASSIFICATION`

Canonical authority:

`integration/f-ci-canonical@412592b874111f35404171f223d3f2518bcad32e`

Parent authority:

- MIQUAL06: `QUALIFIED_MIQUAL06_SERIALIZED_RUNTIME_SEAM`;
- MIQUAL07: `MIQUAL07_DYNAMIC_REFERENCE_BLOCKED`.

## Purpose

Search the existing repository for a dynamic serialized-reference workload that can serve as unbiased LEGACY-versus-manager benchmark authority inside the already-qualified MIQUAL06 manager envelope.

This workunit is acquisition/audit only. It may not invent a new forcing/tolerance combination.

## Required workload properties

A candidate must already exist in repository-backed source or qualified test material and must satisfy all of:

- serialized-reference runtime;
- dynamic physical evolution;
- completed transaction/candidate publication;
- no RossFast;
- no macropore;
- no accepted-trajectory direction service;
- no temporal-history/model-certificate continuation;
- no root extraction;
- no drainage response;
- no snow/soil-temperature/Black/Boesten/fixed-weir process;
- no direct-retention route;
- SWKIMPL=0;
- conductivity mean method=1;
- explicit fixed-flux top;
- fixed-flux bottom mode 2;
- qbot=0;
- zero source/sink arrays;
- no post-exposure tuning needed.

## Candidate families to inspect

At minimum:

- FKT22 serialized trajectory runtime;
- FMR44R prescribed-qbot serialized runtime;
- FGC real-FMR participant tests;
- PPA-WU02 prescribed-qbot application tests;
- FMR23 reference ET runtime;
- existing BOFEK wet/adaptive trajectory tests;
- performance workload catalog;
- any other serialized-reference test discovered by repository tree inspection.

## Frozen classifications

- `QUALIFIED_MIQUAL08_EXISTING_DYNAMIC_REFERENCE_FOUND`
- `MIQUAL08_NO_EXISTING_DYNAMIC_REFERENCE_IN_MANAGER_ENVELOPE`
- `MIQUAL08_REPOSITORY_EVIDENCE_INCOMPLETE`

## Consequence

If no existing workload qualifies, do not silently loosen MIQUAL06 eligibility. Open a separate workunit for either:

1. robust paired equilibrium timing on the already valid production-shaped W0 route; and/or
2. explicit design and qualification of a new transaction-valid dynamic reference workload.

## Production boundary

No runtime behavior or production default changes.
