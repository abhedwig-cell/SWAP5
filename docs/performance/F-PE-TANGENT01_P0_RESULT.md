# F-PE-TANGENT01 P0 result

Date: 2026-09-26

Status: `RUNNING`

Preregistration:

`docs/performance/F-PE-TANGENT01_PREREGISTRATION.md`

Execution harness:

`tests/fpe/run_fpe_tangent01_p0.sh`

This document is intentionally created before interpreting the P0 measurements.

The P0 decision must distinguish:

- a directional implementation defect, where the published tangent fails to match a finite-difference derivative of the same smooth policy response map;
- a path-consistent but temporal-discretization-dependent derivative, where the published tangent matches its own policy response map but differs from the fine Reference derivative.

No production source repair is authorized while this status is `RUNNING`.
