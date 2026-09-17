# Richards discretisation and nonlinear solve

## Scope and authority

This page documents the **frozen reference Richards route** in the Status-A scientific production baseline. It is a technical reference for reviewers; it is not a new numerical specification and it does not widen Status-A scope.

The primary nonlinear owner is the frozen `src/legacy/b1_10_port/headcalc.f90`. The typed reference workspace, state binding and linear-solver modules isolate its state and scratch ownership without changing the admitted reference physics. F-SI35 records that the mandatory production solver seam was completed without changing the full Richards algorithm and without requiring RossFast production readiness.

Post-Status-A Ross/RossFast work is therefore outside the denominator of this page.

## Discrete state and grid

The reference problem uses a one-dimensional vertical compartment grid. For each active compartment `i`, the nonlinear candidate state contains at least:

- pressure head `h_i`;
- volumetric water content `theta_i`;
- hydraulic conductivity `K_i` and internodal mean conductivity `Kmean`;
- the water-capacity derivative used in the Jacobian;
- distributed source and sink terms where admitted.

The accepted start state is kept separately from the nonlinear candidate. In the explicit reference binding, the current candidate fields and the start-of-step history fields are distinct (`h/theta` versus `hm1/thetm1`).

## Storage term

The frozen residual uses the **actual nonlinear water-content difference** between candidate endpoint and accepted start state. For a compartment with thickness `dz_i`, the storage-rate contribution is structurally

```text
S_i = (theta_i - theta_i,start) * f_matrix,i * dz_i / dt
```

where `f_matrix,i` is the applicable matrix fraction. In the restricted non-macropore route this fraction is one.

This is important: the residual does not replace nonlinear storage by a newly invented linear law. The Jacobian uses the constitutive water-capacity derivative as the local linearisation of that nonlinear storage relation.

## Internal hydraulic face term

For an internal face between neighbouring compartments, the frozen owner forms

```text
G_i = (h_(i-1) - h_i) / distance_i + 1
```

and uses the corresponding `Kmean_i * G_i` face term in the compartment residual.

For an interior compartment the residual has the structural form

```text
F_i = S_i
    + sink_i
    - source_i
    + root_sink_i
    - Kmean_i     * G_i
    + Kmean_(i+1) * G_(i+1)
```

within the admitted process envelope.

The `+1` is the gravitational contribution for the frozen vertical coordinate convention. For the physical hydraulic sign convention and the separate normalized accounting sign convention, see [Water balance, signs and units](../science/water-balance-and-conventions.md).

## Boundary insertion into the residual

Boundary conditions are inserted into the same compartment residual; they are not solved in a separate conservation system.

For the two restricted boundary patterns that are particularly important to the current typed interface:

- an explicit prescribed top flux contributes the native solver field `qtop` to the first-compartment residual;
- a prescribed bottom flux contributes `-qbot` to the last-compartment residual;
- a prescribed top head contributes the top hydraulic face term;
- a prescribed bottom head contributes the bottom hydraulic face term.

The native `qtop`/`qbot` solver signs must not be silently replaced by the normalized external-transfer accounting convention. See the boundary and groundwater references for the explicit sign translations at those interfaces.

Historical HeadCalc contains additional lower-boundary branches. Their presence in the source does not make every historical lower-boundary option part of the Status-A claim made by this page.

## Conductivity treatment

Before the nonlinear loop the frozen owner evaluates conductivity for the current time level and constructs the internodal conductivities.

### Restricted `SWKIMPL=0` reference route

For the bounded reference route documented here, conductivity is not differentiated implicitly inside the Newton Jacobian. Across an internal face the two off-diagonal hydraulic couplings are initialized structurally as

```text
-Kmean_i / distance_i
```

and remain the frozen conductivity contribution for that attempted step.

The storage relation itself remains nonlinear through `theta(h)`.

### `SWKIMPL=1`

The historical owner also contains an implicit-conductivity route that evaluates `dK/dh` and adds conductivity-derivative terms to the Jacobian. F-DOC25 records that structural distinction only. It does **not** promote every `SWKIMPL=1` boundary/process combination into Status-A scope.

## Jacobian structure

For the restricted tridiagonal route the Jacobian combines the storage derivative and neighbouring hydraulic conductances.

For an interior compartment, schematically,

```text
J_ii = C_i * f_matrix,i * dz_i / dt
     + conductance_to_upper_face
     + conductance_to_lower_face
```

with the two adjacent off-diagonal entries equal to the negative face conductances in the `SWKIMPL=0` route.

A prescribed-head boundary contributes an additional face stiffness to the relevant main-diagonal entry. A prescribed-flux boundary contributes no state derivative of that prescribed flux.

That distinction is also used by the restricted temporal-indicator operator: a prescribed `qbot` is Neumann and adds zero bottom-head stiffness, whereas prescribed bottom head is Dirichlet and adds the bottom-face stiffness.

## Newton-Raphson update

At each nonlinear iteration the frozen owner:

1. stores the pre-update pressure head;
2. evaluates the current water capacity and any admitted derivative terms;
3. builds the Jacobian;
4. solves the tridiagonal linear system;
5. applies the Newton correction with bounded backtracking;
6. reevaluates water content and the residual;
7. evaluates convergence criteria.

The linear system and update sign are

```text
J * delta_h = F
h_new = h_old - factor * delta_h
```

where `factor` starts at one.

## Backtracking

The frozen route does not blindly accept every full Newton step. After applying a proposed update it recomputes the residual and evaluates

```text
sump = 0.5 * dot(F, F)
Fmax = max(abs(F_i))
```

If the residual objective has not decreased and the maximum compartment residual is not already below the configured compartment-balance criterion, the update factor is reduced by

```text
factor <- factor / 3
```

and another bounded backtracking attempt is made, up to the configured maximum.

There is additional historical logic at the minimum-step boundary that limits excessively large head updates. That behaviour belongs to the frozen owner; it is not generalized here into a new universal step-control rule.

## Linear solve and fallback

The primary reference linear solver is `reference_tridag`.

It performs forward elimination and back substitution on the tridiagonal system. If the first pivot, or a later elimination pivot, is smaller in magnitude than the solver's internal near-zero threshold, the routine reports failure rather than silently continuing the Thomas solve.

The frozen HeadCalc owner then invokes its alternative banded solve for the same one-subdiagonal/one-superdiagonal system. That fallback uses band decomposition with pivoting and back substitution.

This fallback is an implementation property of the frozen reference route. It is not a requirement that future alternative soil-water solvers use the same algorithms.

## Nonlinear convergence tests

After an accepted backtracking update, the frozen owner evaluates multiple criteria.

### Compartment water-balance residual

For every active nonlinear compartment,

```text
abs(F_i) <= CritDevBalCp
```

must hold for the corresponding compartment-balance criterion.

### Pressure-head update

The change from the previous nonlinear iterate is checked with an absolute criterion when the previous head magnitude is smaller than one, and with a relative criterion otherwise:

```text
abs(h_i - h_i,old) <= CritDevh2Cp                       if abs(h_i,old) < 1
abs(h_i - h_i,old) / abs(h_i,old) <= CritDevh1Cp       otherwise
```

### Total residual

The sum of the compartment residuals is also tested against the configured total-balance criterion:

```text
abs(sum(F_i)) <= CritDevBalTot
```

Additional ponding/macropore-specific checks exist in their owning branches. Their historical presence is not used here to broaden the restricted reference claim.

F-DOC25 deliberately assigns **no new numeric values** to any of these criteria. Input/configuration values remain governed by their owning capability and application contracts.

## Failure, retry and state restoration

Failure to meet the nonlinear criteria does not itself authorize a partially mutated endpoint. In the frozen compatibility owner, one failure path restores the pre-step soil state and requests a reduced time step. In the SWAP5 architecture, the surrounding transaction layer additionally owns candidate assessment, retry, rollback and commit.

The architectural invariant is therefore stronger than "HeadCalc converged":

```text
accepted start state
      |
      v
nonlinear candidate solve
      |
      v
solver result / diagnostics
      |
      v
transaction assessment
   /          \
accept        reject
  |             |
commit        rollback / bounded retry
```

A converged numerical candidate is not automatically committed model state.

## Workspace and state ownership

`mod_reference_richards_workspace` owns solver scratch such as:

- residual and Newton correction arrays;
- three Jacobian diagonals;
- linear-solver scratch/factors;
- source/sink buffers;
- constitutive provider buffers;
- conductivity derivatives;
- vertical flux and hydraulic-gradient arrays;
- convergence flags and diagnostics.

`mod_reference_richards_state_binding` owns the explicit reference-facing binding of physical/state-history quantities used by HeadCalc. This separation lets the compatibility solver run behind the typed service without making its scratch arrays authoritative committed model state.

## Restricted temporal indicator is a different operator

`mod_reference_richards_temporal_indicator` is an **auxiliary** restricted operator. It is not the nonlinear Richards residual described above.

For a converged candidate and a previously available right derivative it forms

```text
D_now = (h_candidate - h_start) / dt

e_raw = 0.5 * dt * (D_now - D_previous)

M_i = C_i(candidate) * dz_i
```

It then builds a separate tridiagonal defect operator with mass term `M/dt` and hydraulic face stiffnesses, solves one additional tridiagonal system, and reports mass-weighted norms and a derived pressure-head bound.

Its source envelope is intentionally fail-closed. Among other restrictions, the frozen implementation defers macropore and root-sink cases, requires its admitted conductivity policy and provider types, requires a fixed explicit top flux, and only handles its admitted lower-boundary modes.

F-SI38 explicitly does **not** select a universal application head budget and does not turn this operator into a universal nonlinear Richards true-error theorem. Use it only through a capability-specific admission chain that actually composes it.

## Mass conservation versus nonlinear convergence

Newton convergence and mass acceptance are related but distinct checks. The nonlinear residual contains local conservation equations, but a successful nonlinear iteration does not permit a later hard mass gate to be ignored.

A rejected trial may expose provisional storage and flux information for diagnostics. Those provisional transfers do not become committed mass accounting. See [Water balance, signs and units](../science/water-balance-and-conventions.md) and the [Mass-accounting contract](../verification/mass-accounting-contract.md).

## What this authority does not prove

This reference numerical authority does not establish:

- RossFast or another alternative solver as part of the frozen Status-A denominator;
- a universal iteration tolerance, time step or maximum iteration count;
- a universal nonlinear true-error theorem;
- a universal temporal head-error budget;
- monotonic improvement of every indicator as the time step is shortened;
- admissibility of every historical lower-boundary, macropore or conductivity-policy combination;
- permission for a numerical indicator to override a hard mass failure;
- permission for rejected candidate state to leak into committed state;
- a requirement that future solvers use Newton-Raphson, TRIDAG, the banded fallback or factor-of-three backtracking.

## Reviewer checklist

For an exact review of the frozen reference route, check:

- the actual `theta(candidate)-theta(start)` storage term;
- source/sink and boundary signs in `vector_F`;
- internal hydraulic face gradients and mean conductivities;
- consistency of the Jacobian with the residual for the active conductivity policy;
- prescribed-head stiffness versus prescribed-flux zero derivative;
- `J * delta_h = F` followed by `h <- h - factor*delta_h`;
- residual-objective and factor-of-three backtracking behaviour;
- compartment-balance, head-update and total-balance convergence tests;
- TRIDAG failure handling and the banded fallback;
- separation of workspace scratch, candidate physical state and committed state;
- capability-specific preservation evidence at the frozen production postimage.

The current umbrella authority map is [Status-A traceability](../status-a/TRACEABILITY.md). F-DOC25's detailed claim/source matrix is recorded in `integration/f-doc/F-DOC25_AUTHORITY_MATRIX.md`.
