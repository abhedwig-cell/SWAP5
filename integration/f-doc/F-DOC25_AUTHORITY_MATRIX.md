# F-DOC25 authority matrix — Reference Richards numerical technical reference

F-DOC25 is a documentation-only work unit. It does not create new numerical authority. It reconciles already accepted scientific, production and qualification evidence into a reviewer-facing numerical reference.

## Frozen review denominator

- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`

Post-Status-A Ross/RossFast work is outside this denominator.

## Primary numerical owners

| Surface | Frozen owner | Frozen blob | Permitted documentation claim |
| --- | --- | --- | --- |
| nonlinear residual, Jacobian, Newton/backtracking and convergence logic | `src/legacy/b1_10_port/headcalc.f90` | `3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55` | Exact bounded description of the frozen reference HeadCalc route, including residual structure, Jacobian structure, Newton update sign, backtracking rule and convergence tests. |
| tridiagonal solve and banded fallback implementation | `src/solver/mod_reference_linear_solver.f90` | `5b6ecd2341b315967bcfac6b879c3afe227fb245` | Exact algorithmic description of `reference_tridag`, singular-pivot failure signalling and the one-sub/one-super-diagonal band-solver fallback. |
| solver scratch/workspace | `src/solver/mod_reference_richards_workspace.f90` | `74f99556005ae39614f9df678467b1e19097bae2` | Workspace ownership, scratch separation and diagnostic storage; not scientific theory by itself. |
| explicit reference state binding | `src/solver/mod_reference_richards_state_binding.f90` | `a2488ce3a6a6eff665a59d3dd68907d26f8304ec` | Explicit mapping of pressure head, water content, boundary/state fields and historical state required by the frozen solver seam. |
| restricted temporal indicator | `src/solver/mod_reference_richards_temporal_indicator.f90` | `b648502dea7dfd5de8279bcfa06908c705dcfd2f` | Restricted auxiliary defect/head-bound operator only. It is not the primary Richards discretisation and is not a universal error theorem. |

## Admission and qualification chain

F-SI35 records the mandatory production soil-water solver seam as complete and canonically admitted through F-VQ68 / F-CI58. It explicitly states that the full Richards algorithm was not changed by that work and that RossFast production readiness was not required.

The Status-A traceability map subsequently includes the Richards / soil-water admitted core in the frozen production baseline and points reviewers back to the capability-specific qualification and admission records for exact source ownership.

F-SI38 independently qualifies a restricted prescribed-`qbot` temporal-indicator source capability. Its own hard nonclaims remain binding: it does not select a universal head budget, does not introduce new Richards physics or transaction policy, and does not admit the deferred macropore/root-sink/dynamic-top indicator envelope.

## Claim ceilings

### Residual and storage

F-DOC25 may document that the frozen reference residual uses the actual nonlinear endpoint water-content change

```text
(theta_i - theta_i,start) * dz_i / dt
```

with the applicable matrix fraction, distributed source/sink terms and vertical Darcy-face terms. This does not license replacing the frozen nonlinear storage relation by an invented linear storage law.

### Hydraulic face term

For an internal face, the frozen HeadCalc route uses the hydraulic-gradient quantity

```text
G_i = (h_(i-1) - h_i) / distance_i + 1
```

and the corresponding face term `Kmean_i * G_i` in the compartment residual. This statement is bounded to the frozen vertical sign convention and does not redefine the normalized external mass-accounting sign convention.

### Jacobian

For the restricted `SWKIMPL=0` route, the off-diagonal hydraulic coefficients are based on `-Kmean/distance`, while the main diagonal contains the water-capacity storage derivative plus the adjacent hydraulic conductances and applicable head-boundary stiffness.

`SWKIMPL=1` adds conductivity-derivative terms. F-DOC25 may identify that structural difference, but it does not promote every historical `SWKIMPL=1` option/boundary combination as Status-A scope.

### Newton and backtracking

The frozen owner solves

```text
J * delta_h = F
h_new = h_old - factor * delta_h
```

with `factor` initially one. If the trial update does not reduce the residual objective and the compartment maximum residual is not already below its balance criterion, the backtracking factor is divided by three, bounded by the configured maximum number of backtracking attempts.

No numerical value for a tolerance or iteration budget is elevated to a universal SWAP5 rule by F-DOC25.

### Linear solve

The primary tridiagonal solve performs the standard forward elimination/back-substitution over the three diagonals. A near-zero elimination pivot reports failure. The frozen HeadCalc route then invokes the general banded one-sub/one-super-diagonal fallback.

This is an implementation property of the reference route, not a requirement on future alternative solvers.

### Convergence versus commit

HeadCalc numerical convergence is candidate-solver authority only. Transaction-level assessment, acceptance, retry, rollback and commit remain outside the nonlinear solver and are governed by the transaction architecture.

## Restricted temporal indicator

The temporal-indicator source computes an auxiliary estimate only for its explicit fail-closed envelope. Within that envelope it forms

```text
right_derivative_now = (h_candidate - h_start) / dt
raw_defect = 0.5 * dt * (right_derivative_now - right_derivative_previous)
M_i = C_i(candidate) * dz_i
```

and solves a separate tridiagonal defect operator. Prescribed `qbot` is Neumann and therefore adds zero bottom-head stiffness; prescribed bottom head is Dirichlet and contributes the bottom-face stiffness.

The operator is not the production nonlinear residual and must not be described as though it were.

## Explicit nonclaims

F-DOC25 does not establish:

- RossFast or another post-Status-A solver as part of the frozen Status-A denominator;
- a universal nonlinear error theorem;
- a universal temporal head budget;
- universal numerical tolerances, maximum iterations or time steps;
- admissibility of unsupported macropore, root-sink, dynamic-top or lower-boundary combinations;
- that every solver must use Newton, TRIDAG, banded fallback or factor-of-three backtracking;
- that a numerically converged candidate is automatically committed model state.
