# State, solver and hydraulic core

**Part of:** [Legacy-to-target migration map](legacy-migration.md)  
**Baseline:** SWAP 4.3.1

| Legacy file | Migration action | Target destination(s) | Migration intent |
| --- | --- | --- | --- |
| `MOD_Kavg_Szym.f90` | `RETAIN_NUMERICS_EXTRACT` | Soil-water solver implementation / constitutive utilities | Keep numerical method behind solver/constitutive interfaces; table input must not leak file I/O into kernel. |
| `MOD_MvG_functions.f90` | `RETAIN_PHYSICS_EXTRACT` | Shared soil hydraulic constitutive service; Soil-water solver interface | High-value reusable physics. Make functions explicit/pure where possible and independent of global arrays/pointers. |
| `MOD_RIA.f90` | `RETAIN_REVIEW_DECOUPLE` | Shared soil hydraulic constitutive service | Keep required mathematics/types, but remove global-pointer/allocation coupling and clarify immutable parameter ownership. |
| `WC_K_models_04_11.f90` | `RETAIN_PHYSICS_EXTRACT` | Shared soil hydraulic constitutive service | Preserve qualified hydraulic relations behind stable constitutive interface. |
| `arrays.f90` | `DECOMPOSE` | Data domains; Runtime storage; worker scratch | Distinguish storage helpers from global ownership. Persistent arrays, immutable arrays and scratch must migrate to different owners/layouts. |
| `boundbottom.f90` | `RETAIN_PHYSICS_EXTRACT` | Soil-water solver boundary contract; coupling boundary data | Represent bottom head/flux boundary explicitly. Direct groundwater coupling values arrive through typed boundary input. |
| `boundtop.f90` | `SPLIT_RETAIN_PHYSICS` | Surface/atmospheric boundary physics; Soil-water solver boundary contract | Preserve surface/boundary equations but remove solver-internal/global control coupling. Expose boundary residual/flux contributions explicitly. |
| `calcgwl.f90` | `RETAIN_PHYSICS_EXTRACT` | Soil-water hydraulic query/results service | Keep physical derivation as solver-independent query/diagnostic where feasible; do not let consumers inspect solver arrays directly. |
| `frozencond.f90` | `RETAIN_OPTIONAL_PHYSICS` | Soil-water optional physics; boundary/process interface | Preserve physical effect behind clean source/constitutive/boundary contracts; optional state/cost only when active. |
| `functions.f90` | `SPLIT` | Shared utilities; constitutive service; adapters | Move each function by semantics. Avoid a generic utility dumping ground and remove hidden global dependencies. |
| `headcalc.f90` | `DECOMPOSE_CORE_SOLVER` | Soil-water solver implementation; Surface boundary interface; optional-process interfaces; worker scratch | Retain qualified Richards mathematics but separate residual/Jacobian/linear solve, boundary contributions, other-physics source terms, attempt status and retry policy. No other module may depend on HeadCalc internals. |
| `hysteresis.f90` | `RETAIN_OPTIONAL_PHYSICS` | Soil-water solver/constitutive optional physics | Preserve if active; allocate state only for columns/templates using hysteresis. |
| `params.f90` | `SPLIT` | Shared immutable parameters; numerical configuration | Separate physical constants/parameters from solver tolerances and policy. |
| `soilwater.f90` | `SPLIT_AND_REPLACE_FACADE` | Kernel interval executor; Soil-water solver interface; committed state; Runtime retry policy | Extract solver-independent soil-water contract. State checkpoint/endpoint semantics become transactional; solver selection/retry policy becomes explicit. |
| `sptabulated.f90` | `RETAIN_NUMERICS_EXTRACT` | Shared constitutive/numerical utility | Keep interpolation capability if required by supported physics, with explicit immutable table data. |
| `tridag.f90` | `RETAIN_NUMERICS` | Soil-water solver implementation / numerical utilities | Retain qualified tridiagonal/banded numerical kernels as solver-private utilities or replace with equivalently qualified implementation. |
| `variables.f90` | `DECOMPOSE_AND_RETIRE_GLOBALS` | Committed column-state domain; shared parameters; forcing; numerical configuration; results | Major migration hotspot. Classify every variable by ownership/lifetime, move it to typed domains, then retire broad mutable globals. |

## PR1103 bounded analytical certificate candidate, 2026-10-16

Status: proposed and implemented only on the existing hydraulic candidate; no canonical admission.

The full unchanged B1.11 `MOD_MvG_functions.f90` is the independent executable
value authority for MODEL2 and MODEL3. The MODEL2 dry water-content floor uses a
default-real `1.0000001` literal, rounded before promotion to double precision.
The port must preserve this value, including its effect on conductivity. This
corrects the port; it changes neither the reference nor the admitted default MvG.

The existing Reference temporal certificate may use the stateless MODEL2/3
provider only on its smooth positive-storage branch: base and candidate water
content must be strictly above the MODEL2 floor, or strictly between residual and
saturated content for MODEL3; conductivity and candidate capacity remain strictly
positive under the existing checks. The provider has no timestep-dependent
storage term. MODEL6 remains deferred until its separate literal WC_K oracle is
qualified. Saturated, dry-floor and other compositions receive no new certificate.

Only provider dispatch and this explicit input-domain check may change. The
mass-weighted raw/defect norms, tridiagonal operator, head budget, history contract,
solver and acceptance thresholds remain the incumbent equations. Required evidence
is literal values/cutoffs, an independent dense defect-operator oracle, real dynamic
accepted mass/state with measured predecessor, discard/retry/restart, and current
owner preservation. A component PASS alone cannot admit the runtime. Original
negative provider-envelope evidence remains historical and immutable.
