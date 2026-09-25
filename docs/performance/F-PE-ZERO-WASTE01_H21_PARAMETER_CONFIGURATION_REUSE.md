# F-PE-ZERO-WASTE01 H21 — serialized parameter configuration storage reuse

Date: 2026-09-25

Status: `IMPLEMENTED_PENDING_QUALIFICATION`

## Observation

Every kernel interval calls the bound model's `configure_parameters(parameters)`.

On the serialized B1.10 backend this routine previously deallocated and reallocated, on every call:

- the soil-parameter object;
- the prepared hydraulic-parameter object;
- the constitutive provider object;
- the source/sink provider object;
- the root-sink provider object;
- soil geometry arrays `z`, `dz` and `node_distance`.

The contents do need to be refreshed because a worker can execute different columns. The allocation itself is not required when the object already exists and the geometry shape is unchanged.

## H21 hypothesis

Retaining object allocation and geometry capacity across repeated `configure_parameters` calls preserves exact runtime semantics while removing allocation churn.

The repair does not cache parameter values by identity. Every scalar and array value is still overwritten from the current parameters. Geometry arrays are resized whenever active-node count changes.

Provider objects remain rebound on the physical advance path exactly as before.

## Scope

H21 changes allocation lifecycle only.

It does not:

- assume `parameter_set_id` implies immutable contents;
- skip parameter copying or compatibility checks;
- change hydraulic preprocessing;
- change provider bindings;
- change solver configuration;
- change transaction or accepted-state semantics.

## Qualification gates

1. Existing production application bootstrap gate PASS.
2. Existing FKT22 serialized runtime/reference gate PASS.
3. Parameter preprocessing gate PASS.
4. Cases with repeated equal node count remain physically identical.
5. A changed active-node count must still resize geometry arrays correctly.
6. Existing optional-process configuration gates remain authoritative.
7. No runtime speed claim until paired/end-to-end measurement is available.

## Interpretation

This is P0 zero-waste: capacity is reused, data are not reused.

The distinction is important. H21 removes memory-management work without introducing an immutable-parameter cache contract.
