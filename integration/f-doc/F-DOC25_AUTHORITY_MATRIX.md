# F-DOC25 authority matrix — reference Richards numerics

## Purpose

F-DOC25 expands the numerical reference without changing the frozen scientific denominator. The matrix below separates the primary nonlinear Richards owner from supporting workspace, state-binding, linear-solver and temporal-indicator code. It is a documentation-control artifact, not a new scientific authority.

Frozen review denominator:

- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`

## Primary ownership

| Topic | Frozen owner | Blob | Permitted documentation claim |
| --- | --- | --- | --- |
| Nonlinear Richards residual, Jacobian, iteration and convergence | `src/legacy/b1_10_port/headcalc.f90` | `3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55` | Exact bounded residual/Jacobian/backtracking/convergence semantics for the frozen reference route. |
| Solver request/result ABI and numerical configuration | `src/solver/mod_soil_water_solver_contract.f90` | `276941d76ba951a89c43899e61fd0532418d8230` | Typed ownership of base state, boundaries, numerical configuration, candidate result and diagnostics. |
| Reference scratch/workspace | `src/solver/mod_reference_richards_workspace.f90` | `74f99556005ae39614f9df678467b1e19097bae2` | Workspace is solver-owned scratch/diagnostic state, not accepted physical authority. |
| Tridiagonal and band linear solvers | `src/solver/mod_reference_linear_solver.f90` | `5b6ecd2341b315967bcfac6b879c3afe227fb245` | TRIDAG is the normal linear solve; a general band solve is available as the explicit fallback after TRIDAG failure. |
| Explicit state binding | `src/solver/mod_reference_richards_state_binding.f90` | `a2488ce3a6a6eff665a59d3dd68907d26f8304ec` | Binds base state/boundary data into the reference owner without making the binding itself a new numerical method. |
| Optional temporal indicator | `src/solver/mod_reference_richards_temporal_indicator.f90` | `b648502dea7dfd5de8279bcfa06908c705dcfd2f` | Separate restricted post-solve indicator with an explicit applicability envelope; not the primary discretisation or a universal error theorem. |

## Residual claim ceiling

For the documented non-macropore reference route, the nonlinear owner uses the actual endpoint water-content difference over the attempted step. For an interior compartment the structure is

```text
F_i = (theta_i^1 - theta_i^0) dz_i / dt
      + sink_i - source_i + root_sink_i
      - Q_(i-1/2) + Q_(i+1/2)
```

with the code-level face-gradient convention

```text
G_(i+1/2) = (h_i - h_(i+1)) / d_(i+1/2) + 1
Q_(i+1/2) = K_(i+1/2) G_(i+1/2)
```

The top and bottom terms are replaced by the admitted boundary contribution for that route. This permits documentation of prescribed-flux and prescribed-head structure, but does not authorize an exhaustive catalogue of every historical `SWBOTB` option.

For `SWKIMPL=0`, internodal conductivity is frozen for the nonlinear iteration. The documented Jacobian therefore contains:

- a storage-capacity term `C_i dz_i / dt` on the main diagonal;
- fixed face-conductance terms `-K/d` on adjacent diagonals;
- the corresponding positive conductance contributions on the main diagonal;
- admitted boundary-face stiffness where a head boundary applies.

F-DOC25 does not promote the `SWKIMPL=1` conductivity-derivative terms into the frozen Status-A reference claim.

## Nonlinear solve claim ceiling

The reference iteration solves the tridiagonal system for a correction `delta_h` and updates

```text
h_trial = h_old - factor * delta_h
```

The normal linear route is `reference_tridag`. If that routine reports failure, the owner invokes the general band solver fallback.

The backtracking objective is

```text
phi(F) = 0.5 * F^T F
```

A trial correction is accepted for iteration progress when either:

- `phi(F_trial) < phi(F_previous)`, or
- the maximum absolute compartment residual is already below the compartment-balance tolerance.

Otherwise the correction factor is divided by three and the trial is repeated up to the configured bounded backtracking count. A narrow minimum-step/late-iteration correction limiter exists in the historical owner; F-DOC25 records it only as historical implementation detail and does not elevate it to a general solver policy.

## Convergence claim ceiling

The owner represents separate convergence checks for:

- absolute compartment water-balance residual;
- pressure-head change, using an absolute criterion when `|h_old| < 1` and a relative criterion otherwise;
- absolute total residual sum;
- applicable ponding/surface criteria.

The exact tolerances are supplied through the numerical configuration / historical input authority. F-DOC25 does not invent universal values.

Numerical convergence yields a candidate solver state. It does not authorize transaction commit and does not, by itself, prove whole-model mass closure.

## Temporal-indicator claim ceiling

The temporal indicator is available only inside the explicit envelope implemented by `mod_reference_richards_temporal_indicator.f90`. Among its preconditions are:

- the primary solve converged;
- a previous right derivative is available;
- no active macropore route;
- no bound root-sink provider;
- `conductivity_implicit_mode = 0`;
- `conductivity_mean_method = 1`;
- fixed explicit top flux;
- lower boundary mode 2 (prescribed flux) or 5 (prescribed head);
- the expected B1.10 constitutive and source/sink providers.

It computes the current discrete right derivative

```text
r_n = (h_candidate - h_base) / dt
```

and raw temporal defect estimate

```text
e_raw = 0.5 * dt * (r_n - r_(n-1)).
```

With `m_i = C_i(candidate) dz_i`, the indicator builds a restricted tridiagonal defect operator, performs exactly one additional tridiagonal solve, and performs no additional full nonlinear solve. Its reported norms are

```text
raw_m_norm     = sqrt(sum(m_i * e_raw_i^2))
defect_m_norm  = sqrt(sum(m_i * delta_i^2))
bounded_m_norm = min(raw_m_norm, 2 * defect_m_norm)
head_inf_bound = bounded_m_norm / sqrt(min_i m_i)
```

These quantities are an available model-owned indicator only within that envelope. They are not documented as a universal nonlinear Richards true-error theorem, a monotonic timestep theorem, or a hard acceptance override.

## Explicit non-claims

F-DOC25 does not establish any of the following:

- RossFast as part of the frozen Status-A denominator;
- `SWKIMPL=1` as the reference route;
- macropore numerical qualification;
- every legacy lower-boundary mode as currently admitted typed functionality;
- universal tolerances or a universal timestep;
- automatic commit after nonlinear convergence;
- temporal-indicator authority outside its explicit envelope;
- a guarantee that historical nonconverged continuation semantics are canonical transaction semantics.
