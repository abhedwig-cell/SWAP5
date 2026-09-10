# F-PM07 Soil Temperature Process Boundary, State and Migration Readiness

## Decision scope

This work unit is readiness-only. It does not qualify production physics and does not change `src/` or `reference/`.

The existing branch was a stale reservation at `fafeebdece209abcc320b24a3c8c2757800b2e0e`. That head is not production source authority. The source inventory separately pins the current canonical context and the exact audited SWAP 4.3.1 legacy source archive. Any implementation child must start clean from the canonical authority valid at that later time.

## Source-bound process identity

Legacy `MOD_SoilTemperature` contains two different temperature providers behind `SoilTemperature(Task)`:

1. an analytic annual-wave provider, which materializes a temperature profile from time, depth and immutable parameters;
2. a numerical one-dimensional heat-conduction provider, which advances a vertical temperature profile using De Vries heat capacity/conductivity and thermal top/bottom boundary conditions.

These share the output concept `soil temperature by node`, but they do not require the same persistent state. The target process interface must therefore permit provider-specific state rather than allocating the numerical profile state to every column.

## True temporal cadence and legacy ordering

The numerical heat process is not fundamentally daily. In the main legacy timestep loop the ordering is:

`forcing -> snow at day-start if enabled -> frost reduction from existing temperature -> root extraction -> bottom boundary -> drainage -> water trial/retry -> accepted SoilWater state/rates -> water integrals -> SoilTemperature(2) -> solute -> time advance`.

Therefore:

- numerical soil temperature is advanced once for each successful soil-water timestep;
- rejected water trials do not currently advance `tsoil`;
- frost, temperature-dependent hydraulic conductivity and root/oxygen-stress calculations consume the previously materialized temperature profile during the water solve;
- after the water solve, the numerical temperature update uses `0.5*(theta + thetm1)`;
- this is a sequential, lagged thermal-hydraulic coupling and must be preserved in reference migration unless a later qualification explicitly changes it.

The analytic provider is called on the same process cadence, but its formula uses integer `daynr` with `omega = 2*pi/365`. That is a legacy calendar dependency, not evidence that one day is a kernel time unit. A target provider must accept generic time and reproduce legacy calendar semantics only where the selected formulation requires them.

The snow routine has a separate legacy day-start cadence. Snow timing must remain owned by the snow process, not by soil temperature.

## Data decomposition

### Immutable thermal parameters

For the numerical provider, immutable/shared parameter data include:

- mineral and organic composition inputs used to derive quartz, clay and organic volume fractions;
- porosity/layer mapping used in those derived fractions;
- material heat capacities and densities;
- material thermal conductivities and De Vries shape/weight constants;
- top and bottom thermal boundary-condition type;
- prescribed thermal boundary schedules as immutable forcing definitions, not mutable state.

`fquartz`, `fclay`, `forg` and precomputed De Vries constants are derived parameter/cache data. They can be shared by columns with the same soil/thermal parameter reference. They are not continuation state.

For the analytic provider, `tmean`, `tampli`, `timref` and `ddamp` are immutable formulation parameters.

### Forcing

The temperature process may consume:

- air temperature;
- prescribed soil-surface temperature where configured;
- prescribed soil-surface heat flux where configured;
- prescribed bottom temperature where configured;
- generic current time for interpolation/evaluation;
- snow thermal state through an explicit snow-to-thermal boundary view when snow is active.

Legacy interpolation cursors `ipos_qtop`, `ipos_tetop` and `ipos_tebot` are acceleration state only. They are recomputable and belong in worker/job scratch or a forcing adapter cache, not persistent column physics state.

### Persistent temperature state

For the numerical provider the minimal physical continuation state is:

`temperature_profile[1:n_active_nodes]`.

This is source-bound by two independent observations in the legacy code:

- on restart (`swinco == 3`) numerical initialization deliberately does not overwrite `tsoil`;
- restart serialization stores `TSOIL` when heat simulation is enabled.

No evidence requires `heacap`, `heacon`, `TeTop`, `TeBot`, interpolation cursors, matrix vectors or frost-reduction arrays as persistent restart state.

For the analytic provider there is no evolution state in the formula. The node profile is a materialized result of time, depth and immutable parameters. The legacy restart file may contain `TSOIL` because restart serialization is shared across heat modes, but analytic initialization recomputes the profile. The target should therefore not require a persistent per-column temperature vector for analytic mode unless later exact-restart evidence shows a separate need.

For `SWHEA=0`, no soil-temperature process state should be allocated. A default/materialized temperature used by downstream legacy consumers is configuration/result materialization, not evidence for an evolving heat-state object.

### Hydraulic and water-content inputs

The numerical heat provider requires volumetric water content for the current and previous physical states, or an equivalent explicitly defined interval-average water-content view. It does not need HeadCalc arrays.

The current canonical `process_hydraulic_view_t` already exposes water content at process level. A temperature implementation may use such a view or a narrower dedicated water-content view. It must not import HeadCalc or soil-water solver workspace internals.

There is also a reverse dependency in the legacy source: hydraulic conductivity models 4 through 12 can consume `tsoil(node)`. This does not make soil temperature part of HeadCalc. The target boundary should instead expose a read-only temperature-field view to the selected constitutive provider. During a reference-compatible water trial that view is the committed temperature at the start of the interval.

### Crop, root and biogeochemical consumers

Legacy consumers include:

- root extraction and frost suppression of uptake;
- oxygen-stress calculations;
- crop sowing/development thresholds;
- WOFOST temperature-sum logic in one mode;
- solute decomposition temperature correction;
- soil management/nutrient calculations;
- external/output interfaces.

These modules should consume an explicit read-only temperature-field view. They must not own or mutate soil-temperature state.

### Results

Candidate process results are:

- temperature profile at the accepted interval end;
- optional surface and bottom boundary temperatures;
- optional derived heat capacity and heat conductivity profiles for diagnostics/output;
- thermal boundary flux diagnostics where the formulation can expose them unambiguously.

`heacap` and `heacon` are derived from water content plus immutable thermal parameters. They are results/scratch, not continuation state.

### Scratch

Worker/job scratch includes at least:

- previous-temperature working copy `tmpold`;
- tridiagonal vectors `thoma`, `thomb`, `thomc`, `thomf`, `thomx`;
- interval-average water content `theave`;
- nodal/face thermal conductivity work arrays such as `heacnd`;
- temporary snow-resistance and boundary-flux terms;
- interpolation cursors if retained as an optimization.

These arrays must not be permanently allocated per logical MultiSWAP column.

### Diagnostics

Runtime diagnostics should be able to identify:

- selected temperature provider;
- active node count;
- thermal boundary modes;
- number and cost of thermal solves;
- rejected thermal trials, if a future implementation can reject;
- min/max accepted temperature;
- top/bottom heat-flux terms where available;
- energy residual once an explicit energy-accounting contract has been qualified;
- whether frost and snow coupling were active.

## Frost ownership

Frost is not part of the numerical heat-equation owner in the audited source.

`MOD_frost` consumes `tsoil` and `tetop`, derives `rfcp`, frost depths and a deepest frozen node, and then modifies hydraulic conductivity, drainage and bottom flux. No explicit ice-content state or latent-heat term was found in `MOD_SoilTemperature`.

The target decomposition is therefore:

- Soil Temperature owns temperature evolution/materialization.
- Frost Hydraulic Modifier owns the mapping from temperature to hydraulic restrictions.
- Soil Water owns water state and constitutive solution.
- Drainage owns drainage physics and accepts an explicit frost constraint/modifier where required.

The legacy frost implementation directly imports hydraulic/drainage internals, including `MOD_MvG` and mutable drainage arrays. That dependency is not an acceptable target interface. It must be replaced by process-facing hydraulic/drainage contracts in a separate child work unit.

`rfcp`, `nodfrostbot`, `zfrosttop` and `zfrostbot` are derivable from committed temperature plus frost parameters and current geometry. No restart serialization for them was found. They should therefore be recomputed rather than persisted unless later qualification demonstrates a hidden lifecycle dependency.

The current incompatibility `SWFROST=1` with macropore flow is a physical-option constraint. Migration must preserve it until a separate physics qualification explicitly changes it.

## Snow boundary

Snow is a separate process owner. When snow storage is present, legacy soil temperature computes a soil-snow interface temperature from air temperature, current top-node soil temperature and snow thermal resistance. The target should express this through a small thermal boundary contract, not by sharing snow module globals.

Any change to the snow/soil heat-transfer formula or its cadence is outside F-PM07 readiness and requires separate qualification.

## Transaction contract

A target interval `[t0,t1]` must satisfy:

1. checkpoint committed temperature state at `t0` when the numerical provider is active;
2. all hydraulic trial/retry work reads the correct committed temperature view and cannot mutate it;
3. after an acceptable hydraulic trial exists, compute a temperature trial using the physical interval inputs defined by the reference ordering;
4. keep the resulting temperature profile in trial state;
5. commit water and temperature states only when the full interval is accepted by the runtime transaction;
6. if any later process rejects the interval, discard the temperature trial and restore the same committed temperature state at `t0`;
7. warm-start data may be retained only as scratch and can never substitute for the committed physical state.

This preserves the legacy property that a rejected water trial cannot advance temperature while making rollback explicit for the new runtime.

## Restart contract

Minimum restart payload by mode:

| Heat mode | Required persistent payload | Recomputable |
| --- | --- | --- |
| inactive | none | any default/materialized temperature output |
| analytic | none expected from source-bound formula | full profile from time, depth and analytic parameters |
| numerical | `temperature_profile[1:n]` | heat capacity, conductivity, boundary values, matrix work, interpolation cursors |

A later implementation qualification must prove split-run equality for every active provider and for relevant snow/frost combinations. It must also prove that immutable soil/thermal parameters remain shared by reference/ID rather than copied into every column state.

## Energy accounting boundary

Water mass conservation remains absolute and is not altered by this process decomposition.

For heat, the legacy numerical solver represents sensible heat storage and conduction through water-content-dependent heat capacity/conductivity. F-PM07 did not find a persistent or cumulative energy ledger, and the frost mechanism does not introduce explicit ice storage or latent heat in the temperature equation.

Therefore F-PM07 does not claim a closed thermodynamic energy balance for legacy frost/heat physics. Before production migration, a separate qualification must define:

- what energy storage quantity is accounted;
- top and bottom heat-flux sign conventions;
- whether any source/sink terms exist;
- residual calculation over `[t0,t1]`;
- the relationship, if any, between the empirical frost hydraulic modifier and an energy/phase-change model.

That child must preserve existing reference physics unless a separate physics-change program is explicitly opened.

## Optional-state and MultiSWAP footprint

The target layout should scale with active physics:

- no temperature state for heat-disabled columns;
- no evolving temperature state for analytic-provider columns unless later restart qualification requires it;
- one compact node-temperature vector for numerical-provider columns;
- no per-column permanent tridiagonal workspace;
- shared thermal parameter blocks by parameter/template ID;
- frost-derived arrays only when frost is active, and preferably as worker/result scratch because they are recomputable;
- homogeneous execution classes may group columns by heat provider, discretization and active snow/frost coupling without changing physics.

## Ownership boundaries

| Concern | Owner | Soil Temperature interaction |
| --- | --- | --- |
| temperature evolution/materialization | Soil Temperature | owns |
| immutable thermal material properties | parameter store/template | reads/shared reference |
| meteorological temperature and prescribed thermal BC schedules | forcing/boundary provider | reads |
| water content | Soil Water physical state/view | reads only |
| pressure head, Newton arrays, Jacobian | Soil Water solver | no access required |
| temperature effect on hydraulic constitutive relation | selected hydraulic constitutive provider | consumes read-only temperature view |
| frost hydraulic restriction | Frost Hydraulic Modifier | consumes temperature, does not own it |
| drainage response to frost | Drainage + Frost contract | no direct temperature-state mutation |
| snow insulation/top thermal boundary | Snow + thermal boundary adapter | explicit view/contract |
| crop/root/oxygen response | crop/root processes | consume temperature view |
| solute/nutrient temperature response | solute/nutrient processes | consume temperature view |
| transaction/rollback | runtime | orchestrates trial and commit |
| persistent-state serialization | runtime persistence | serializes numerical temperature state only when active |
| energy residual diagnostics | thermal diagnostics/accounting | separate qualified contract required |

## Child work units

The following implementation/qualification units are required after this readiness closeout. Names are reservations of responsibility, not production authority.

1. **F-PM07A Thermal Data Contract**: define immutable thermal parameters, forcing/boundary views, provider selection and generic-time semantics. Include exact legacy analytic-day behavior as a compatibility provider without making day a kernel unit.
2. **F-PM07B Temperature State and Transaction Contract**: implement compact provider-specific persistent state, checkpoint/trial/commit/rollback and split-run restart tests.
3. **F-PM07C Numerical Heat Provider Candidate**: isolate the De Vries plus tridiagonal conduction path behind the process interface with worker-owned scratch and reference-mode equivalence evidence.
4. **F-PM07D Frost Hydraulic Modifier Boundary**: separate frost from temperature ownership; remove direct solver/drainage internal coupling; preserve current physical restrictions, including unsupported frost-plus-macropore combinations, until independently requalified.
5. **F-PM07E Snow-Thermal Boundary Contract**: isolate snow-insulation/top-boundary exchange and qualify temporal ordering with the snow process.
6. **F-PM07F Temperature Consumer Views**: bind crop, root uptake, oxygen stress, solute, nutrient and hydraulic constitutive consumers to a read-only temperature-field interface without global module access.
7. **F-PM07G Thermal Energy Accounting Qualification**: define sensible-energy storage/flux accounting and residual diagnostics; explicitly classify legacy frost/phase-change limitations.
8. **F-PM07H MultiSWAP Thermal Layout Qualification**: qualify optional-state packing, shared parameter references, worker scratch, homogeneous batching and bounded per-column memory.
9. **F-VQ-PM07 Independent Production Qualification**: only after the implementation children are complete, compare against the exact reference authority for continuous runs, retries, split runs, snow/frost combinations and relevant temperature-dependent hydraulic models.

## Readiness disposition

The soil-temperature domain is sufficiently decomposed to start isolated child work without importing the legacy module boundary into the new kernel.

The qualified readiness boundary is intentionally narrower than production qualification:

`QUALIFIED_SOIL_TEMPERATURE_MIGRATION_READINESS`

This does not qualify migrated temperature code, changed frost physics, an energy-balance claim, or production admission.
