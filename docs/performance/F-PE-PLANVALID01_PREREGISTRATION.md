# F-PE-PLANVALID01 — serialized execution-plan construction

Date: 2026-09-25

Status: `PREREGISTERED`

Production parent: `f5ba657695156a936cb3dc8e14669f92d333753b`.

## Question

Can the one-time serialized execution-plan build for the canonical production-bootstrap layout be reduced from quadratic to linear or near-linear work without changing generic validation, execution order, template mapping, failure behavior, physics or repeated runtime?

## Source decomposition

Current `fmr_build_serialized_execution_plan()` performs three potentially scale-sensitive operations:

1. `execution_plan_registry_valid()`: pairwise template duplicate checks and pairwise column-id/state-handle duplicate checks;
2. `fmr_build_execution_order()`: insertion sort;
3. per-column `execution_plan_find_template()`: linear template search.

Production bootstrap allocates one template record per column and preserves tile order, so the current canonical N=10,000 fixture can expose quadratic work in both validation and template-index resolution.

## Preregistered measurement

Measure direct execution-plan build at N=1, 100, 1,000 and 10,000, separately from application initialization.

No production patch is authorized until the baseline is recorded.

## Candidate boundary

A fast path may be admitted only under a runtime proof that the input is already canonical and one-to-one:

- positive strictly increasing template IDs;
- positive strictly increasing column IDs;
- positive strictly increasing state handles within state_count;
- column template ID equals the same-position template ID;
- therefore uniqueness, order and template index are all proven directly.

If any proof clause fails, the historical generic path remains authoritative.

This design preserves generic semantics and avoids changing failure behavior for noncanonical/invalid inputs by falling back before any generic result is returned.

## Required gates

- canonical fast path exact plan identity versus generic construction;
- reverse/mixed/noncanonical valid inputs use generic path and retain identical plan;
- duplicate template, duplicate column ID, duplicate state handle, invalid state handle and nonpositive IDs remain rejected;
- N=1/100/1000/10000 paired runtime;
- repeated MultiSWAP interval result and runtime semantics unchanged;
- no production physics/numerical changes.

## Classification

`A + F`: avoidable one-time structural work in application setup.
