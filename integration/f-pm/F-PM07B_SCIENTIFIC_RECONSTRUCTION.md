# F-PM07B Scientific Reconstruction and Restricted-Profile Reconciliation

## Evidence basis

This reconstruction is source-bound to the exact F-PM07 legacy pin and to the post-RB1 implementation base recorded in `F-PM07B_SCOPE_AND_AUTHORITY.md`.

Audited legacy source:

- archive: `SWAP_4.3.1(6).zip`, SHA-256 `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`;
- inner source archive: `SWAP.ZIP`, SHA-256 `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`;
- `SWAP/temperature.f90`, SHA-256 `92c39d296f41a60cfe3b66f8d1886ea938a53b4e0ea49e7ae1a23dd9680bd338`.

The target candidate does not copy the legacy module boundary. It reconstructs one bounded physical route from the actual equations and places that route behind explicit SWAP5 data and transaction contracts.

## Selected physical route

The restricted candidate is the numerical sensible-heat conduction route with:

- prescribed soil-surface temperature, legacy `SWTOPBHEA=2` semantics after interpolation has already been performed outside the process;
- zero lower heat flux, legacy `SWBOTBHEA=1`;
- no snow;
- no frost hydraulic modifier;
- no latent heat or ice state;
- no analytic annual-wave provider;
- no air-temperature surface mode;
- no prescribed heat-flux or mixed top boundary;
- no prescribed bottom temperature.

The excluded routes fail by absence from the candidate interface. They are not silently mapped onto the supported route.

## Spatial placement and geometry

The legacy numerical heat equation uses the same compartment/node geometry as soil water. For node `i`:

- `dz(i)` is the represented compartment thickness in cm;
- `disnod(i)` is the distance between node `i-1` and node `i`, with `disnod(1)` representing the surface to top-node distance;
- nodal thermal capacity is evaluated at the node;
- internal face conductivity is the arithmetic mean of the two adjacent nodal conductivities;
- at the surface face the top-node conductivity is used directly.

The candidate therefore accepts immutable geometry `dz_cm` and `distance_above_cm`. It does not infer geometry from solver arrays and does not access HeadCalc.

## Hydraulic input and temporal ordering

The legacy numerical route evaluates thermal material properties with

`theta_bar(i) = 0.5 * (theta(i) + thetm1(i))`.

F-PM07 established that this happens after an accepted soil-water timestep. The water solve itself consumes the previously committed temperature profile where legacy temperature feedback is active. Therefore the source-bound reference ordering is sequential and lagged:

1. hydraulic trial/retry starts from committed temperature at `t0`;
2. an accepted water state provides start/end water-content views;
3. the thermal candidate forms `theta_bar`;
4. the thermal solve produces a trial temperature profile for `t1`;
5. publication of that profile is a separate commit operation.

The F-PM07B process accepts two `process_hydraulic_view_t` values and reads only `water_content`. It has no dependency on pressure-head arrays, Newton vectors, Jacobians or a particular Richards implementation.

## Sensible heat capacity

For each node the legacy De Vries implementation computes the air volume fraction

`f_air = max(0, theta_sat - theta)`

and volumetric sensible heat capacity

`C = (f_q rho_q c_q + f_c rho_c c_c + f_o rho_o c_o + theta rho_w c_w + f_air rho_a c_a) * 1e-6`.

The retained units are `J cm-3 K-1`.

Constants retained exactly from the audited source are:

| constituent | specific heat `J kg-1 K-1` | density `kg m-3` | conductivity `W m-1 K-1` |
| --- | ---: | ---: | ---: |
| quartz | 800 | 2660 | 8.8 |
| clay | 900 | 2650 | 2.92 |
| water | 4180 | 1000 | 0.57 |
| air | 1010 | 1.2 | 0.025 |
| organic matter | 1920 | 1300 | 0.25 |

### Theory/code unit discrepancy

The legacy `DeVries` routine header labels `HeaCap` as `J/m3/K`, and a nearby implementation comment even says `W/m3/K`. The implementation itself multiplies the mass-based constituent capacities by `1e-6`, while the module declaration labels `heacap` as `J/cm3/K`. The timestep matrix also requires the latter unit when combined with cm geometry and conductivity in `J cm-1 K-1 day-1`.

Classification:

`RESOLVED_DOCUMENTATION_UNIT_DISCREPANCY`

The candidate retains the implemented and dimensionally consistent `J cm-3 K-1` unit. It does not preserve the erroneous routine-header unit label.

## Thermal conductivity

The De Vries weighting factors and source constants are retained exactly. Shape factors are:

- quartz `0.14`;
- clay `0.125`;
- water `0.14`;
- organic matter `0.5`.

The empirical regime thresholds are `thetaDry = 0.02` and `thetaWet = 0.05`.

For air, legacy code derives a water-relative weighting factor from a moisture-dependent air shape factor. Conductivity is then evaluated in three explicit regimes:

1. `theta <= 0.02`: dry expression with the legacy empirical factor `1.25`;
2. `theta >= 0.05`: wet expression;
3. `0.02 < theta < 0.05`: linear interpolation between dry and wet endpoint conductivities.

The final conversion factor `864` converts `W m-1 K-1` to `J cm-1 K-1 day-1`.

Independent test oracles exercise all three regimes. F-PM07B does not replace them by one smoothed approximation.

## Material fractions

Legacy initialization derives `fquartz`, `fclay` and `forg` from `orgmat`, texture fractions and saturated water content using rounded density-related factors `0.370`, `0.714`, `2.7` and `1.4`. These derived fractions are immutable thermal material data after initialization.

The restricted process accepts the already-derived fractions as thermal parameters. This is deliberate:

- process physics does not own legacy soil-input parsing;
- the fractions can be shared by parameter/template ID;
- a later adapter or parameter-construction qualification can reproduce the legacy derivation without making it continuation state.

F-PM07B validates non-negativity and a bounded solid fraction, but does not invent an exact `solid + porosity = 1` equality that the rounded legacy derivation itself does not guarantee.

## Fully implicit timestep equation

For each internal node `i`, define upward-face conductivity `K_i`, downward-face conductivity `K_{i+1}`, node capacity `C_i`, thickness `dz_i`, and adjacent-node distances `d_i`, `d_{i+1}`. The audited code forms

`a_i = -dt K_i / (dz_i d_i)`

`c_i = -dt K_{i+1} / (dz_i d_{i+1})`

`b_i = C_i - a_i - c_i`

and solves

`a_i T_{i-1}^{n+1} + b_i T_i^{n+1} + c_i T_{i+1}^{n+1} = C_i T_i^n`.

This is a fully implicit linear solve for the interval after material properties have been evaluated from the accepted interval-average water content.

### Surface Dirichlet boundary

For the selected `SWTOPBHEA=2` route the prescribed surface temperature is eliminated into the first-node right-hand side:

`rhs_1 = C_1 T_1^n - a_1 T_surface`.

The candidate forcing contains only the already materialized surface temperature for the requested interval. There are no interpolation cursors, file names or table arrays in process code.

### Zero-flux lower boundary

For selected `SWBOTBHEA=1`, the bottom heat flux is zero. The bottom row therefore has no lower external-neighbour coefficient and becomes

`a_N T_{N-1}^{n+1} + (C_N - a_N) T_N^{n+1} = C_N T_N^n`.

No synthetic bottom temperature is needed by the target route.

## Sign convention and restricted energy accounting

F-PM07B defines top heat flux as positive **into the soil**:

`q_top = K_surface (T_surface - T_1^{n+1}) / d_surface`.

For this restricted route there are no internal heat sources and the lower flux is zero. Therefore the sensible-energy identity over the interval is

`Delta E_sensible = dt * q_top`

with

`Delta E_sensible = sum_i C_i dz_i (T_i^{n+1} - T_i^n)`.

The candidate reports

`energy_residual = Delta E_sensible - dt * q_top`.

The candidate can require this residual to remain within an explicit numerical tolerance. This is a qualification/accounting gate for the supported sensible-heat formulation. It is **not** a claim of a complete thermodynamic energy balance for frost, snow or phase change.

## Generic time

The numerical formulation depends on `dt = t1 - t0`. No day, month, year, midnight, `daynr` or `t1900` concept is required by the process. Legacy table interpolation against `t1900` belongs to an external forcing adapter.

The candidate therefore accepts arbitrary finite `t0 < t1`. Time is not implicitly a daily process cadence.

## Transaction and restart semantics

The only physical continuation state for the numerical candidate is the active-node temperature vector.

A trial:

- receives committed temperature with `intent(in)`;
- uses worker-owned scratch for the old profile, interval-average moisture, thermal properties, face properties and tridiagonal vectors;
- materializes a separate trial state only after the numerical solve and requested accounting gate succeed;
- never mutates the committed state.

Commit is explicit. Discarding a trial therefore leaves the committed profile unchanged without a restorative write.

The restart payload contains only:

- schema version;
- active temperature profile.

All thermal properties, matrix arrays, interpolation state and boundary values are recomputable and are not serialized.

## Consumer boundary

The state owner exposes a semantic `soil_temperature_field_view_t` and node query. Future hydraulic-constitutive, crop, root, oxygen, solute or nutrient consumers must use such read-only thermal information rather than importing the internal temperature array or numerical workspace.

F-PM07B does not yet wire those excluded consumers into production execution. Their scientific activation remains separately qualified.

## Frost and snow disposition

The audited legacy code does not solve latent heat or ice content in `MOD_SoilTemperature`. Frost restrictions are applied separately by `MOD_frost`, and snow insulation changes the thermal surface boundary through separate snow state.

Consequently:

- frost is excluded from this candidate and remains a separate hydraulic-modifier owner problem;
- snow is excluded from this candidate and remains a separate thermal-boundary contract problem;
- neither is approximated, disabled behind a legacy switch, or silently ignored after being requested.

## Reconstruction disposition

For the selected route, documented theory, actual code, units after correcting the legacy header error, sign convention, node placement, boundary equations and numerical discretisation are mutually consistent enough to implement a bounded candidate.

No unresolved theory/code discrepancy remains inside the supported restricted profile.

This statement does not qualify excluded boundary modes, analytic temperature, snow, frost, latent heat, or full soil-temperature production coverage.