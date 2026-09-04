# Data ownership

The target kernel makes ownership explicit. This is a correctness requirement for rollback and coupling, and a scaling requirement for MultiSWAP.

## Data categories

| Category | Lifetime | Typical content | Ownership |
| --- | --- | --- | --- |
| Parameters | long-lived, usually immutable | soil hydraulic parameters, crop parameters, drainage configuration | shared objects referenced by ID where possible |
| Dynamic state | persistent per active column | pressure head, water content, ponding, physically required module storage | column state |
| Forcing | interval-specific | precipitation, meteorology, imposed boundary data | caller/runtime supplies to kernel |
| Numerical configuration | configuration lifetime | tolerances, timestep policy, reference/balanced/throughput policy | runtime or execution template |
| Results | produced per request | fluxes, endpoints, diagnostics, coupling response | returned by kernel |
| Scratch | trial/job lifetime | Newton vectors, residuals, Jacobians, constitutive intermediates | worker or compute job |

## Persistent state rule

A column stores only information needed to continue its physical evolution. An inactive optional module must not allocate persistent state merely because another column uses that module.

Immutable soil, crop and other parameter sets should be shared by reference rather than duplicated per column.

## Scratch rule

Temporary nonlinear-solver data does not belong to the persistent column state. Worker-owned scratch allows allocation reuse across many columns without multiplying Jacobian and Newton storage by the number of logical columns.

This also makes the transaction boundary clearer: rollback restores physical state, not a large collection of numerical work arrays.

## State and warm starts are different

A warm-start guess may be retained for performance, but it is not authoritative physical state. A failed or rejected trial must not alter the committed physical endpoint.

If a warm start is invalidated or unavailable, correctness must remain unchanged. Only computational cost may change.

## Logical API versus storage layout

The public API may expose clear per-column objects while internal storage uses structures of arrays, pools or batches. The logical data model therefore must not prescribe a one-object-per-column memory layout.
