# F-PM07B Legacy Soil-Temperature Variable and State Audit

## Classification rule

Every declared variable in the audited `MOD_SoilTemperature` source, plus the imported dynamic dependencies that determine ownership, is assigned one of the requested categories:

`PARAMETER`, `PERSISTENT_STATE`, `FORCING`, `RESULT`, `SCRATCH`, `LEGACY_IO_ONLY`, or `OBSOLETE`.

For cross-process dynamic inputs, `FORCING` means read-only input to the thermal process. In SWAP5 these are exposed by semantic process views, not necessarily by the atmospheric forcing object.

Only `PERSISTENT_STATE` is eligible for thermal continuation/restart state. A legacy `SAVE` attribute by itself is not evidence of persistence.

## Module-level variables

| Legacy variable | Classification | Target disposition |
| --- | --- | --- |
| `tsoil` | `PERSISTENT_STATE` | Numerical provider continuation state. Only active-node values persist. Analytic provider would not require this state. |
| `tetop`, `tebot` | `RESULT` | Recomputable/materialized boundary values. Not restart state. F-PM07B only materializes the prescribed surface temperature and zero bottom flux. |
| `heacap`, `heacon` | `SCRATCH` | Derived thermal properties/face conductivities. Worker-owned scratch, optionally exposed diagnostically later. |
| `ntembottab`, `ntemtoptab`, `ntgtoptab` | `LEGACY_IO_ONLY` | Legacy table lengths. Boundary-provider/adapter concern, never kernel state. |
| `swbotbhea`, `swtopbhea` | `PARAMETER` | Physical boundary-mode selection. F-PM07B fixes the supported profile to top Dirichlet temperature plus zero bottom flux rather than carrying legacy integer switches. |
| `nheat` | `LEGACY_IO_ONLY` | Initial-profile table length. Used while constructing initial state only. |
| `tembottab`, `temtoptab`, `tgtoptab` | `LEGACY_IO_ONLY` | Legacy time tables. Replaced by external boundary/forcing materialization. |
| `fclay`, `forg`, `fquartz` | `PARAMETER` | Derived immutable thermal material fractions, shareable by parameter/template reference. |
| `ipos_qtop`, `ipos_tetop`, `ipos_tebot` | `SCRATCH` | Interpolation acceleration cursors. Adapter/worker cache only; recomputable and not serialized. |
| `fkk_QCO_dry`, `fk_QCO_dry`, `fkk_QCO_wet`, `fk_QCO_wet` | `PARAMETER` | Derived immutable De Vries parameter cache. F-PM07B precomputes them in the parameter object. |
| `GAir`, `GAirdry` | `SCRATCH` | Constitutive intermediates. Legacy made these mutable module globals even though they are call-local quantities. F-PM07B makes them scalar local scratch. |

### Module physical constants

All named constants below are `PARAMETER`. They are formulation constants, not per-column dynamic state:

- `kaa`, `kww`;
- `cQuartz`, `cClay`, `cWat`, `cAir`, `cOrg`;
- `dQuartz`, `dClay`, `dWat`, `dAir`, `dOrg`;
- `kQuartz`, `kClay`, `kWat`, `kAir`, `kOrg`;
- `GQuartz`, `GClay`, `GWat`, `GOrg`;
- `thetaDry`, `thetaWet`;
- `kqw`, `kcw`, `kow`, `kwa`, `kqa`, `kca`, `koa`;
- `kAirDIVkWat`;
- `cdQuartz`, `cdClay`, `cdWat`, `cdAir`, `cdOrg`;
- `kqaXkQuartz`, `kcaXkClay`, `kaaXkAir`, `koaXkOrg`, `kwaXkWat`, `kqwXkQuartz`, `kcwXkClay`, `kowXkOrg`, `kwwXkWat`.

F-PM07B retains the source-bound constants needed by the restricted numerical provider. They are compile-time formulation parameters and create no per-column footprint.

## `SoilTemperature` dispatcher

| Variable | Classification | Target disposition |
| --- | --- | --- |
| `Task` | `OBSOLETE` | Legacy lifecycle integer dispatch. Replaced by explicit initialization, trial, commit, view and persistence calls. |
| imported `swcalt` | `PARAMETER` | Legacy provider-selection switch. F-PM07B exposes only the numerical restricted provider and therefore does not import it. |

## `temperature_numeric`

### Imported dependencies

| Legacy variable | Classification | Target disposition |
| --- | --- | --- |
| `tav` | `FORCING` | Air temperature. Used only by excluded legacy air/snow top-boundary paths. |
| `swinco` | `OBSOLETE` | Legacy restart/initial-condition mode switch. SWAP5 persistence reconstructs state explicitly. |
| `ssnow` | `FORCING` | Snow-process state/view. Excluded from F-PM07B and reserved for a separate snow-thermal boundary contract. |
| `orgmat`, `pclay`, `psand`, `psilt` | `PARAMETER` | Soil composition input used to derive immutable thermal material fractions. F-PM07B consumes the derived fractions. |
| `theta`, `thetm1` | `FORCING` | Dynamic soil-water input. Mapped to start/end process-facing water-content views. |
| `numnod` | `PARAMETER` | Grid size metadata. Mapped to `active_nodes`. |
| `z` | `PARAMETER` | Node depth geometry. Needed for legacy initialization/analytic provider; not required by the restricted conduction equations once distances/thicknesses are supplied. |
| `dz`, `disnod` | `PARAMETER` | Immutable thermal grid geometry in cm. |
| `numlay` | `PARAMETER` | Layer-count metadata used during parameter construction. |
| `t1900` | `FORCING` | Legacy absolute time coordinate used only for table interpolation. Removed from process code; adapter concern. |
| `dt` | `FORCING` | Interval duration. Target receives generic `t0,t1` and computes `dt=t1-t0`. |
| `thetsl` | `PARAMETER` | Saturated water content used in material-fraction derivation. Target stores `theta_sat`. |

### Declared numerical variables

| Legacy variable | Classification | Target disposition |
| --- | --- | --- |
| `tsoiltb` | `LEGACY_IO_ONLY` | Temporary initial-temperature table. Values are consumed to construct initial `PERSISTENT_STATE`; table itself is not retained. |
| `task` | `OBSOLETE` | Legacy lifecycle dispatcher. |
| `tmpold` | `SCRATCH` | Old-temperature working copy. Worker scratch. |
| `thoma`, `thomb`, `thomc`, `thomf`, `thomx` | `SCRATCH` | Tridiagonal coefficients/RHS/solution. Worker scratch. |
| `theave` | `SCRATCH` | Interval-average water-content work vector. Worker scratch. |
| `heacnd` | `SCRATCH` | Nodal thermal-conductivity work vector. Worker scratch. |
| `i`, `lay`, `ipos`, `ierror` | `SCRATCH` | Loop/index/status temporaries. `ipos` is initialization interpolation position only. |
| `dummy`, `gmineral` | `SCRATCH` | Parameter-construction intermediates. |
| `heaconbot`, `qhbot` | `SCRATCH` | Bottom-boundary work quantities. `qhbot=0` for the F-PM07B route. |
| `QTtop` | `FORCING` | Materialized top heat-flux boundary value for excluded legacy modes 3/4. |
| `apar`, `dzsnw`, `heaconsnw`, `Rosnw` | `SCRATCH` | Snow-boundary intermediates. Excluded from F-PM07B and not allocated there. |
| `message` | `SCRATCH` | Legacy error-message work buffer. No physical state. |

## Nested `DeVries`

### Imported/deferred dependencies

| Legacy variable | Classification | Target disposition |
| --- | --- | --- |
| imported `THETAS` | `PARAMETER` | Saturated volumetric water content. F-PM07B parameter `theta_sat`. |
| imported `numlay`, `layer` | `PARAMETER` | Layer metadata/mapping. F-PM07B stores material data at active nodes so the runtime solve needs no legacy layer globals. |

### Arguments and locals

| Legacy variable | Classification | Target disposition |
| --- | --- | --- |
| `iTask` | `OBSOLETE` | Legacy initialize/evaluate dispatcher. Target parameter construction and evaluation are separate routines. |
| `theta` argument | `FORCING` | Read-only interval-average hydraulic input. |
| `HeaCap`, `HeaCon` arguments | `SCRATCH` | Derived constitutive work arrays in the candidate. |
| `Node` | `SCRATCH` | Loop index. |
| `kaw` | `SCRATCH` | Air-to-water weighting factor. |
| `fAir` | `SCRATCH` | Air-volume work vector. Legacy `SAVE` is unnecessary; F-PM07B computes it transiently. |
| `HeaConDry`, `HeaConWet` | `SCRATCH` | Conductivity endpoint intermediates for transition regime. |

## `read_soiltemperature`

The whole routine is an adapter concern. None of its declared values is valid kernel/process continuation state.

| Legacy variable | Classification | Target disposition |
| --- | --- | --- |
| `unit_tss` | `LEGACY_IO_ONLY` | File unit. |
| `gc` | `LEGACY_IO_ONLY` | Input-table scaling value for heat-flux file. |
| `z_ini`, `t_ini` | `LEGACY_IO_ONLY` | Deprecated initial-profile input buffers. |
| `tsoilfile`, `TGsoilfile`, `filnam` | `LEGACY_IO_ONLY` | File names/paths. |
| `message` | `LEGACY_IO_ONLY` | I/O error-message buffer. |
| `file_exists` | `LEGACY_IO_ONLY` | File-system status. |
| external `getun2`, `rdinqr` | `LEGACY_IO_ONLY` | Legacy file/parser services, not physical data. |
| imported `iun_min2`, `iun_max2`, `unit_swp`, `swpfilnam`, `pathwork`, `unit_err`, `fl_initialize` | `LEGACY_IO_ONLY` | File-unit/path/parser/runtime-I/O control. |
| imported `tstart`, `tend` | `LEGACY_IO_ONLY` | Used to validate input-table coverage. The process itself receives already-materialized forcing over generic time. |

## `read_tab_bc`

| Legacy variable | Classification | Target disposition |
| --- | --- | --- |
| `nvals` | `LEGACY_IO_ONLY` | Table length. |
| `tstart`, `tend`, `minval`, `maxval`, `factor` | `LEGACY_IO_ONLY` | Parsing/validation/scaling inputs. |
| `table` | `LEGACY_IO_ONLY` | Parser output table, consumed by a forcing adapter rather than process state. |
| `description`, `variable` | `LEGACY_IO_ONLY` | Parser metadata strings. |
| `i` | `SCRATCH` | Loop index inside adapter helper. |
| `dates`, `bc_vals` | `LEGACY_IO_ONLY` | Temporary parsed table vectors. |

## `temperature_analytic`

The analytic provider is explicitly outside F-PM07B, but its variables are classified to prevent accidental state inflation in later work.

| Legacy variable | Classification | Target disposition |
| --- | --- | --- |
| `task` | `OBSOLETE` | Legacy lifecycle dispatcher. |
| `i` | `SCRATCH` | Loop index. |
| `pi` | `SCRATCH` | Initialization intermediate. |
| `halfpi`, `omega` | `PARAMETER` | Derived analytic formulation constants. They need not be persistent state. |
| `ddamp`, `tampli`, `timref`, `tmean` | `PARAMETER` | Immutable analytic-provider parameters. |
| imported `numnod`, `z` | `PARAMETER` | Geometry. |
| imported `daynr` | `FORCING` | Calendar-dependent time input specific to the analytic compatibility provider. It must not redefine kernel time. |
| imported `unit_swp`, `swpfilnam`, `unit_err` | `LEGACY_IO_ONLY` | Legacy parameter parsing. |

## Pure function `T_anal`

| Variable | Classification | Target disposition |
| --- | --- | --- |
| `daynr` | `FORCING` | Calendar input for analytic provider only. |
| `z`, `tmean`, `tampli`, `halfpi`, `omega`, `timref`, `ddamp` | `PARAMETER` | Geometry/formulation inputs. |
| `T_anal` | `RESULT` | Materialized temperature value. No evolution state. |

## Persistent-state conclusion

The audit finds exactly one genuinely persistent variable family for the selected numerical capability:

`temperature_profile[1:active_nodes]`.

Everything else is one of:

- immutable/shared parameter data;
- read-only interval input;
- recomputable result;
- worker scratch;
- legacy I/O machinery;
- obsolete lifecycle dispatch.

In particular, the following legacy `SAVE` data are **not** continuation state and must not be serialized per column: `heacap`, `heacon`, `GAir`, `GAirdry`, boundary tables, interpolation cursors, `tmpold`, Thomas vectors, `theave`, `heacnd`, and `fAir`.

This is the basis for the F-PM07B restart payload and MultiSWAP memory layout.