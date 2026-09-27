# F-PE-TEMPORAL10 preregistration — demand-directed temporal constitutive evaluation

Date: 2026-09-28

Status: `PREREGISTERED_RESEARCH_CANDIDATE`

## Parent evidence

TEMPORAL09 measured constitutive reevaluation at about 53% of temporal-service time and roughly 12% of physical-backend critical-path time at N=40,000.

The existing temporal indicator performs two full constitutive evaluations although it consumes only:
- base-state conductivity;
- candidate-state water content;
- candidate-state capacity.

## Candidate

Research-only candidate in a temporary source copy:

- replace the full base constitutive evaluation with `evaluate_demand(..., CONSTITUTIVE_DEMAND_CONDUCTIVITY, ...)`;
- replace the full candidate constitutive evaluation with two bounded demand calls:
  - `CONSTITUTIVE_DEMAND_WATER_CONTENT`;
  - `CONSTITUTIVE_DEMAND_CAPACITY`.

The candidate deliberately uses separate candidate water-content and capacity calls. This preserves the table-backed direct-retention provider semantics; a combined demand would currently fall through to its analytical provider.

Generic constitutive providers remain semantically protected by the existing demand fallback, which delegates to full `evaluate`.

## Frozen benchmark

Paired baseline/candidate:
- N = 1,000 / 10,000 / 40,000;
- worker=4 primary;
- worker=1 secondary;
- 5 repetitions after warm-up;
- production-shaped MULTI04 workload.

Required:
- exact q checksum;
- exact response-tangent checksum;
- no candidate failure.

## Advancement gate

Advance to production repair only if:
- N=40,000 worker=4 end-to-end trial speedup >=5%;
- N=10,000 worker=4 speedup >=3%;
- no >2% regression at N=1,000 worker=4;
- worker=1 has no material regression.

Before production admission, add direct temporal-indicator equivalence evidence proving exact certificate outputs and history semantics for admitted default-MvG and direct-retention routes.

## Production boundary

No production `src/**` change in this qualification phase.

## Governance

RECONCILE → QUALIFY → REPAIR → ADMIT → CLOSE.
