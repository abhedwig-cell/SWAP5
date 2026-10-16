# F-PE-TEMPORAL09 closeout — production temporal-history service decomposition

Date: 2026-09-28

Status: `CLOSED_WITH_MATERIAL_CONSTITUTIVE_TARGET`

## Decision

TEMPORAL09 found one dominant temporal-service target.

At N=40,000, worker=4, constitutive reevaluation owns about 53.1% of temporal-service critical-path time. Combined with PHYS01, this is roughly 12% of total physical-backend critical-path time.

Operator assembly is about 10.6% of temporal service and the extra tridiagonal solve only about 2.9%; neither is the first repair target.

## Authorized successor

`F-PE-TEMPORAL10` — demand-directed temporal constitutive evaluation.

The candidate may replace full constitutive evaluations only with existing provider demand calls for quantities already required by the exact certificate:
- base conductivity;
- candidate water content;
- candidate capacity.

Direct-retention water content and capacity remain separate demand calls to preserve table-backed semantics.

No workspace cache authority, approximation or certificate relaxation is authorized.

## Production boundary

Observation-only. No production source change from TEMPORAL09.

## Closure

`CLOSED_WITH_MATERIAL_CONSTITUTIVE_TARGET`
