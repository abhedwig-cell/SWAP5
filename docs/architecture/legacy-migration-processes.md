# Surface, drainage, management and optional flow physics

**Part of:** [Legacy-to-target migration map](legacy-migration.md)  
**Baseline:** SWAP 4.3.1

| Legacy file | Migration action | Target destination(s) | Migration intent |
| --- | --- | --- | --- |
| `MOD_drainage.f90` | `RETAIN_PHYSICS_EXTRACT` | Drainage/optional process physics | Retain drainage calculations behind hydraulic/process interface; no direct HeadCalc internals. |
| `divdra.f90` | `RETAIN_PHYSICS_REVIEW` | Drainage/optional process physics | Keep if required by qualified drainage modes; fold into drainage component with explicit inputs. |
| `drainage.f90` | `SPLIT` | Drainage physics; Legacy adapters; shared parameters | Keep drainage laws; move reading/config parsing outward and remove global solver dependencies. |
| `irrigation.f90` | `SPLIT` | Irrigation/process physics; Adapters; forcing/management domain | Separate scheduling/input parsing from physical/source-flux calculation. |
| `macropore.f90` | `DECOMPOSE_OPTIONAL_PHYSICS` | Optional macropore physics; committed state; shared parameters | Preserve macropore physics but separate immutable geometry/parameters, physical state and trial computations. No allocation/cost when inactive. |
| `macrorate.f90` | `RETAIN_OPTIONAL_PHYSICS` | Optional macropore physics | Keep process equations behind explicit hydraulic/surface interfaces. |
| `management_soil.f90` | `SPLIT_RETAIN_PHYSICS` | Management/optional physics; Crop/ET; adapters as needed | Retain physical management effects; remove implicit global scheduling and file/output concerns. |
| `snow.f90` | `RETAIN_OPTIONAL_PHYSICS` | Surface/atmospheric optional physics | Preserve snow state/processes as optional module with explicit forcing/state. |
| `surfacewater.f90` | `SPLIT_RETAIN_PHYSICS` | Surface boundary physics; Drainage optional physics; Coupler if external surface-water composition | Separate in-column surface equations from system-level composition and drainage configuration. See SW-RIB-SWM01 before making any stronger retirement claim. |
| `temperature.f90` | `SPLIT_RETAIN_PHYSICS` | Optional soil-temperature physics; Adapters | Retain thermal model; move parameter/input reading outward; explicit coupling to atmosphere/soil state. |
| `tillage.f90` | `SPLIT_RETAIN_PHYSICS` | Management/optional physics; shared parameters/state | Preserve physical parameter/state modifications through explicit state transition; output side effects removed. |

## Surface-water retirement guard

SW-RIB-SWM01 records an open qualification question for the legacy `surfacewater.f90` responsibility set. Its provisional target split is:

- Ribasim for system-level surface-water state, storage, level, structures, supply and allocation;
- SWAP5 for soil-to-surface-water exchange physics;
- a coupling/management layer for rules that translate accepted SWAP soil state into surface-water management targets.

This is not current production authority and does not authorize retirement of the legacy behaviour. The container or control path may be retired only after the legacy responsibilities have been inventoried and the retained behaviour has been qualified against a real-Ribasim reconstruction.

See [SW-RIB-SWM01: legacy SWAP surface-water ownership decomposition](../integration/SW-RIB-SWM01_SURFACEWATER_OWNERSHIP.md).
