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
| `surfacewater.f90` | `SPLIT_RETAIN_PHYSICS` | SWAP drainage/exchange physics; standalone fixed-weir physics; Ribasim plus coupler in the admitted external-owner profile | In external-Ribasim mode, Ribasim owns the represented surface-water storage/level and system realization; SWAP retains soil/drainage exchange physics and the coupler owns cross-model feasibility. Whole-file retirement is not authorized. |
| `temperature.f90` | `SPLIT_RETAIN_PHYSICS` | Optional soil-temperature physics; Adapters | Retain thermal model; move parameter/input reading outward; explicit coupling to atmosphere/soil state. |
| `tillage.f90` | `SPLIT_RETAIN_PHYSICS` | Management/optional physics; shared parameters/state | Preserve physical parameter/state modifications through explicit state transition; output side effects removed. |


## Canonical surface-water ownership disposition

The post-Status-A canonical line now admits the bounded `RIBASIM_EXTERNAL_SECONDARY_STATE_V1` application profile.

For the same physical secondary surface-water store, ownership is mode-exclusive:

```text
standalone SWAP5:
    SWAP5 F-CI52 may own its qualified restricted fixed-weir surface-water state

Ribasim-coupled profile:
    Ribasim owns accepted surface-water storage and level
    SWAP5 owns signed soil/drainage exchange physics
    the coupler owns cross-model feasibility and accepted transfer ordering
```

The migration consequence for `surfacewater.f90` is therefore decomposition, not wholesale deletion.

Coupled-mode retirement candidates include the legacy local secondary storage container, local surface-water level realization for that store, local supply/discharge realization and parser/control plumbing once their configured responsibilities have an admitted target owner.

Responsibilities that must remain in SWAP or be separately extracted include signed drainage/infiltration constitutive physics, multilevel drainage responsibilities within their admitted envelope, runoff/top-boundary physics, rapid/macropore drainage generation and the separately admitted standalone fixed-weir capability.

Automatic soil-state-driven management remains scientifically decomposed as accepted SWAP state -> management policy -> Ribasim target/realization, but `SWMAN=2` is not yet part of the production-admitted Ribasim profile.

Direct legacy `STTAB` storage-knot mapping to Ribasim is not exact between knots. The default coupled production profile therefore uses Ribasim-native geometry. The separately qualified Q1H epsilon-controlled representation remains a migration/emulation option rather than the default ownership contract.
