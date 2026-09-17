# Restricted Richards temporal indicator

## Purpose

The reference Richards solver exposes an **optional post-solve temporal indicator**. It is not the primary Richards discretisation and it does not perform another nonlinear Richards solve.

Its purpose is to derive a bounded model-owned head-space indicator from a converged reference candidate and the change in the discrete right derivative between consecutive accepted/candidate intervals, but only inside a deliberately restricted numerical and physical envelope.

## Availability envelope

The indicator first requires a converged primary solver result and a valid previous right derivative. It is unavailable outside the explicitly implemented envelope.

The frozen implementation requires, among other conditions:

- no active macropore route;
- no bound root-sink provider;
- `conductivity_implicit_mode = 0`;
- `conductivity_mean_method = 1`;
- a fixed explicit-flux top boundary;
- bottom mode 2 (prescribed flux) or mode 5 (prescribed head);
- the expected B1.10 constitutive provider;
- the expected B1.10 source/sink provider;
- finite compatible base/candidate state and positive grid/mass coefficients.

If an unsupported policy or provider is active, the routine reports the indicator as unavailable rather than silently applying a different formula.

## Discrete right derivative

For the converged candidate it computes

```text
r_n = (h_candidate - h_base) / dt.
```

A previous right derivative `r_(n-1)` must have been supplied by the caller. The raw temporal defect estimate is then

```text
e_raw = 0.5 * dt * (r_n - r_(n-1)).
```

This is a head-space quantity. Its interpretation is bounded by the operator described below and by the explicit availability envelope.

## Mass weighting

The constitutive provider is evaluated at the candidate state. The indicator forms a positive diagonal mass weight

```text
m_i = C_i(candidate) dz_i
```

where `C_i` is the candidate moisture capacity. Nonfinite or nonpositive weights make the indicator fail rather than producing a nominal value.

## Restricted defect operator

The indicator constructs a tridiagonal operator whose diagonal starts with

```text
m_i / dt.
```

For each internal face it computes an arithmetic-mean base-state conductance

```text
a_(i+1/2) = 0.5 * (K_i(base) + K_(i+1)(base)) / d_(i+1/2)
```

and adds the usual symmetric diffusion-like tridiagonal contribution:

```text
lower  -= a
upper  -= a
diagonal(left)  += a
diagonal(right) += a.
```

For prescribed bottom head (mode 5), the bottom face adds

```text
K_N(base) / (0.5 dz_N)
```

to the last diagonal entry. For prescribed bottom flux (mode 2), that boundary contributes no state derivative to this defect operator.

The right-hand side is

```text
rhs_i = (m_i / dt) e_raw_i.
```

The routine then performs one reference tridiagonal solve for `delta`.

## Reported norms

The implementation reports

```text
raw_m_norm = sqrt(sum_i m_i e_raw_i^2)
```

and

```text
defect_m_norm = sqrt(sum_i m_i delta_i^2).
```

The bounded norm is

```text
bounded_m_norm = min(raw_m_norm, 2 * defect_m_norm)
```

and the reported infinity-style head bound is

```text
head_inf_bound = bounded_m_norm / sqrt(min_i m_i).
```

The diagnostics explicitly record:

```text
additional_tridiagonal_solves = 1
additional_full_nonlinear_solves = 0.
```

## Why this is separate from the nonlinear solver

The primary Richards solve determines a candidate state by satisfying the nonlinear compartment residual. The temporal indicator consumes that already-converged candidate afterward. Therefore it does not redefine:

- the residual equations;
- the `SWKIMPL=0` reference Jacobian;
- nonlinear convergence;
- transaction acceptance;
- mass closure.

It is an additional numerical signal only.

## Availability, failure and authority

The routine distinguishes three practically important outcomes:

- **available** — the restricted envelope is satisfied and a finite indicator is returned;
- **unavailable** — the route is outside the admitted indicator envelope or required history is absent;
- **failed** — the requested envelope was entered but invalid shapes, nonfinite state, invalid coefficients or linear-solve failure prevent a valid indicator.

An unavailable indicator is not itself evidence that the primary Richards candidate is wrong. Conversely, an available finite indicator is not authority to override a hard mass or transaction failure.

## Non-claims

This page does not claim:

- a universal nonlinear Richards local truncation-error theorem;
- a global application accuracy guarantee;
- monotonic decrease of `head_inf_bound` under every timestep reduction;
- validity with macropores, root-sink provider coupling, arbitrary conductivity policies or arbitrary boundary modes;
- that the indicator is a hard acceptance criterion;
- that one additional tridiagonal solve is equivalent to a second full Richards solve;
- that the indicator changes the frozen scientific production baseline.

For primary residual/Jacobian semantics, read [Richards discretisation and nonlinear solve](richards-solver.md). For commit/retry ownership, read [Transactional time stepping and acceptance](transactional-time-stepping.md).
