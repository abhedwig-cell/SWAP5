# Richards discretisation and nonlinear solve

## Scope and authority

This page documents the **frozen reference Richards route** in the Status-A scientific review denominator. The primary nonlinear owner is the frozen `src/legacy/b1_10_port/headcalc.f90` implementation at scientific production baseline `50346642bd565f79134ea17d5462e544b354998c`, supported by the typed solver contract, reference workspace and reference linear-solver modules.

The page is deliberately narrower than the full historical option space. In particular, it does not promote `SWKIMPL=1`, macropore numerics, RossFast, or every historical lower-boundary mode into the frozen reference claim.

## State and geometry

The typed solver request provides:

- accepted/base pressure head `h_i` and water content `theta_i`;
- compartment elevations and thicknesses;
- distances between adjacent nodes;
- the attempted step duration `dt`;
- top and bottom boundary data;
- numerical controls and constitutive/source-sink providers.

The solver produces a **candidate** endpoint. The surrounding transaction architecture remains the authority for acceptance, rollback and commit.

## Discrete water-balance residual

The qualified reference formulation is one-dimensional and vertically compartmented. It uses an implicit endpoint balance with the **actual nonlinear water-content difference** between candidate endpoint and accepted start state:

```text
(theta_i^1 - theta_i^0) dz_i / dt
```

For the documented non-macropore route, define the code-level face gradient between adjacent compartments as

```text
G_(i+1/2) = (h_i - h_(i+1)) / d_(i+1/2) + 1
```

and the corresponding face term

```text
Q_(i+1/2) = K_(i+1/2) G_(i+1/2).
```

Then an interior residual has the structure

```text
F_i = (theta_i^1 - theta_i^0) dz_i / dt
      + sink_i - source_i + root_sink_i
      - Q_(i-1/2) + Q_(i+1/2).
```

The sign convention here is the one used inside the residual owner. It must not be confused with the normalized external-transfer sign used by the mass ledger. See [Water balance, signs and units](../science/water-balance-and-conventions.md).

### Top boundary

For a prescribed top flux, the owner adds the top flux term directly to the first-compartment residual:

```text
F_1 = storage + sinks - sources + Q_(3/2) + q_top.
```

For an admitted head-controlled top face, the boundary contribution is represented through

```text
G_(1/2) = (h_surface - h_1) / d_(1/2) + 1
```

and the residual uses the corresponding `-K_(1/2) G_(1/2)` face term.

The scientific meaning and currently documented upper-boundary regimes are described separately in [Hydrological boundary conditions](../science/hydrological-boundary-conditions.md).

### Bottom boundary

The last compartment starts from

```text
F_N = storage + sinks - sources - Q_(N-1/2)
```

and then receives the selected lower-boundary term. For the bounded cases needed here:

- prescribed bottom flux contributes `-q_bottom`;
- prescribed bottom head contributes a bottom face term `+K_b G_b`.

This page does **not** turn that statement into an exhaustive current-authority table for every historical `SWBOTB` branch.

## Frozen-conductivity reference linearisation

The frozen reference `SWKIMPL=0` route resets conductivity to the start-of-step state before the nonlinear loop and keeps the face conductivities fixed during that iteration sequence. Water content remains nonlinear through `theta(h)`, and the moisture capacity `C = d theta / d h` is reevaluated as the pressure-head iterate changes.

For an interior compartment, the resulting tridiagonal Jacobian has the bounded structure

```text
J_(i,i-1) = -K_(i-1/2) / d_(i-1/2)

J_(i,i)   = C_i dz_i / dt
            + K_(i-1/2) / d_(i-1/2)
            + K_(i+1/2) / d_(i+1/2)

J_(i,i+1) = -K_(i+1/2) / d_(i+1/2).
```

A prescribed-head face adds its corresponding `K/d` stiffness to the boundary compartment main diagonal. Prescribed flux does not add a state derivative for that face.

This is the Jacobian of the **restricted frozen-conductivity linearisation** used by the reference route. It is not a claim that conductivity derivatives are absent from all historical or future SWAP solvers.

## Newton correction and linear solve

At each nonlinear iteration the owner builds the residual and Jacobian and solves the tridiagonal system for `delta_h`. The update convention is

```text
h_trial = h_old - factor * delta_h.
```

The normal linear route is `reference_tridag`. If that tridiagonal solve reports failure, the reference owner explicitly switches to the more general band-matrix solver and uses that result as the correction. This fallback is part of the reference numerical implementation; it does not imply a second physical model.

The reference workspace owns the residual, Jacobian diagonals, correction vector, tridiagonal factors, alternative band-solver scratch, convergence flags and diagnostics. These arrays are scratch/diagnostic state. They are not accepted physical model state.

## Backtracking

A full Newton correction is attempted first with

```text
factor = 1.
```

After recomputing the nonlinear residual, the implementation evaluates

```text
phi(F) = 0.5 * F^T F
```

and

```text
F_max = max_i |F_i|.
```

The trial correction is accepted for iteration progress when either:

```text
phi(F_trial) < phi(F_previous)
```

or

```text
F_max < compartment_balance_tolerance.
```

If neither condition is met, the update factor is divided by three and the trial is repeated, bounded by the configured maximum number of backtracking attempts.

The historical owner also contains a narrow correction limiter for late iterations at minimum timestep. That implementation detail is not generalized here into a universal SWAP5 nonlinear-solver policy.

## Convergence criteria

The reference owner keeps distinct convergence tests rather than collapsing them into one scalar criterion.

### Compartment balance

For every active compartment:

```text
|F_i| <= compartment_balance_tolerance.
```

### Pressure-head change

The change from the previous nonlinear iterate uses two branches:

```text
if |h_old| < 1:
    |h_new - h_old| <= head_abs_tolerance
else:
    |h_new - h_old| / |h_old| <= head_rel_tolerance.
```

### Total residual

The summed compartment residual is additionally checked against the configured total-balance tolerance:

```text
|sum_i F_i| <= total_balance_tolerance.
```

Applicable surface/ponding regimes add their own convergence check. Numerical values for these tolerances come from the owning configuration/input authority. This documentation does not invent a universal tolerance set.

## Solver status versus transaction authority

The typed solver contract distinguishes solver result from accepted model state. It can report a converged candidate, advise retry, or report failure; its diagnostics expose iteration, Jacobian, linear-solve, backtracking, fallback and retry counts.

A converged nonlinear state remains a **candidate**. The surrounding transaction layer decides whether scientific/numerical assessment permits commit. Therefore:

```text
nonlinear convergence != transaction commit
```

and

```text
nonlinear convergence != proof of whole-model mass closure.
```

A later hard assessment may still reject a converged candidate, while a failed solve may trigger a bounded retry from accepted authority.

## Temporal accuracy is a separate concern

The reference implementation also exposes a restricted optional temporal indicator. It is intentionally separate from the primary nonlinear solve and has a much narrower applicability envelope. See [Restricted Richards temporal indicator](richards-temporal-indicator.md).

The existence of that indicator does not change the residual solved here and does not create a universal nonlinear true-error theorem.

## What this numerical authority does not prove

The frozen reference authority does not establish:

- RossFast or another alternative nonlinear solver as part of the frozen Status-A review denominator;
- `SWKIMPL=1` as the reference conductivity treatment;
- a universal iteration tolerance;
- a universal timestep;
- a universal nonlinear true-error theorem;
- monotonic improvement of every indicator as timestep decreases;
- permission for a numerical indicator to override a hard mass failure;
- permission for rejected candidate state to leak into committed state;
- canonical adoption of every historical nonconvergence continuation branch.

## What to inspect in code review

Reviewers should check, against the frozen authority chain:

- residual sign and unit consistency;
- correspondence between residual and the `SWKIMPL=0` Jacobian actually solved;
- `theta(h)` and capacity consistency;
- boundary-face contributions;
- source/sink signs and ownership;
- tridiagonal failure and fallback behavior;
- backtracking and convergence branches;
- nonfinite/failure propagation through the typed solver contract;
- separation between solver workspace, candidate state and committed state;
- exact preservation evidence where reference equivalence is claimed.

The current authority map is [Status-A traceability](../status-a/TRACEABILITY.md). F-DOC25 only makes the already-frozen numerical route more explicit; it does not alter the scientific production baseline.
