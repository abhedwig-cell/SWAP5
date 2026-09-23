# Active-irrigation temporal production blocker

The SWAP5–Ribasim management route and the closed SWAP5–MODFLOW6 fixed-interface route can be composed architecturally, but active-irrigation production admission remains blocked by one independent requirement.

The inherited F-GC44 global-head budget is **not authorized** for active irrigation. Same-horizon tests localize the largest pressure-head discrepancy near the surface while preserving column storage and external-transfer totals. The resulting lower-interface and coupled-groundwater effects are small but nonzero.

Current characterized effects for the bounded 8.64 s case include:

- global maximum pressure-head difference: 0.0463838022838558572 cm;
- bottom-node head difference: 0.0000435876321063233263 cm;
- column-storage difference: 0 cm;
- q_swap response difference: 3.46816556953720273e-12 m/s;
- coupled head shift: 1.7051093870179557e-10 m;
- groundwater-transfer shift over 8.64 s and 1 m²: 2.9958798482770209e-11 m³.

These values are **evidence, not acceptance thresholds**.

Production admission may be reopened only when one of the following is supplied prospectively:

1. an application-owner requirement for allowable temporal error in named hydrological outputs;
2. an independent validation authority with such a criterion;
3. a separately preregistered numerical-accuracy requirement justified independently of the observed research outcomes.

Until then, do not tune the tolerance to the current case, do not infer that smaller timesteps are automatically safer, and do not claim a production-admitted active-irrigation SWAP5–MODFLOW6–Ribasim triangle.
