# F-PE-TIMEINT01 — reconstruction of current Richards time discretization

Date: 2026-09-28

Canonical authority:

`integration/f-ci-canonical@bc365f8d24fb1854ee1484a4f6f9dcc5bc3944fb`

## 1. Current compartment residual

For an interior compartment i, current HeadCalc forms:

`R_i = V_i [theta_i(h_i^{n+1}) - theta_i^n] / dt + S_i - Q_i + q_{i+1/2}^{n+1,*} - q_{i-1/2}^{n+1,*}`

where `V_i = matrix_fraction_i * dz_i`.

The storage term is nonlinear in candidate pressure head because theta is recomputed after every Newton/backtracking update.

## 2. Conductivity time level for SWKIMPL=0

Before Newton starts, node conductivities and inter-node means are rebuilt from the accepted/base state.

For `SWKIMPL=0` they are not updated with every Newton candidate.

Therefore interior Darcy flux has the structure:

`q_{i+1/2}^{n+1,*} = -K_{i+1/2}^n * ( grad(h^{n+1}) + 1 )`.

The asterisk matters: candidate head is implicit, but conductivity is lagged.

This is not fully implicit Backward Euler applied to the complete nonlinear Richards operator.

## 3. Storage Jacobian

The Newton diagonal includes:

`C_i(h_i^k) * V_i / dt`

with candidate moisture capacity `C=dtheta/dh`.

Thus the nonlinear storage term is solved consistently with the endpoint theta relation.

## 4. Source and sink time level

Provider source/sink and root-sink vectors are evaluated before the nonlinear iteration loop from the state available at solve start.

Within one HeadCalc call they are treated as constant step terms.

Therefore state-dependent uptake/drainage/provider terms can be lagged even though the pressure-head/storage solve is implicit.

## 5. Dynamic top boundary

Dynamic-top evaluation is candidate-dependent during Newton.

For the admitted fixed-K SWKIMPL=0 route:

- top-node K is frozen from the accepted origin;
- surface head, ponding and runoff can depend on candidate top head and dt;
- in head regime the corrected Jacobian includes
  `K_surface/d * (1 - dHsurf/dh_top)`.

The boundary operator is piecewise smooth because it switches among:

- atmospheric-head;
- surface-flux;
- ponded-head;
- ponded-head with linear runoff.

## 6. Bottom boundary

Bottom-boundary evaluation varies by mode.

Some routes are prescribed flux and therefore explicit in state.

Some head/Cauchy/free-drainage routes depend on candidate head and/or conductivity.

TIMEINT01 therefore does not claim one universal endpoint operator for every bottom mode.

## 7. Compact form

Within a smooth fixed boundary/process regime, the admitted SWKIMPL=0 route can be represented schematically as:

`M(h^{n+1}) - M(h^n) + dt * F(h^{n+1}; K^n, z^n, forcing_n, dt) = 0`.

Here:

- `M` is water storage;
- `F` includes Darcy divergence and step-frozen source/sink information;
- `K^n` denotes lagged conductivity;
- `z^n` denotes other frozen process/provider inputs;
- dynamic-top terms may themselves depend explicitly on dt.

## 8. Formal temporal order

In a smooth regime, this construction is expected to be first-order in time.

Reasons:

1. it is a one-step endpoint method;
2. conductivity is lagged from n to n+1;
3. sources/sinks can be frozen across the interval;
4. no second-order history combination is present.

The nonlinear Newton convergence order is unrelated to this temporal order.

Tighter Newton tolerances cannot turn the time integrator into a higher-order method.

## 9. Boundary-switch order loss

At a dynamic-top regime switch, the time operator is only piecewise smooth.

A single large step may see one endpoint regime while two half steps traverse different regimes.

DYNERR01 demonstrated exactly this:

- full route HEAD;
- first half FLUX;
- second half HEAD;
- severe full/two-half discrepancy despite a small endpoint defect estimate.

At such switching points, a local smooth-regime error model can lose its expected asymptotic behavior.

## 10. Why DTMIN/DTMAX tuning was structurally limited

The current method has no native local truncation-error estimate.

Legacy TimeControl therefore uses nonlinear iteration count as a proxy for future dt.

But nonlinear solve difficulty answers a different question:

`How hard was it to solve the discrete algebraic system?`

Temporal control needs:

`How inaccurate was the accepted discrete trajectory over this interval?`

The two can correlate, but need not.

This explains the TIMEARCH12-17 pattern: useful signal, poor blind generalization.

## 11. Transactional implications

A modern multistep or embedded method must respect current transaction authority.

Rejected attempts must not alter:

- accepted physical state;
- accepted temporal history;
- BDF history;
- controller state;
- process memory.

Only commit may advance temporal-history state.

This is already compatible with the SWAP5 transaction model, but the history payload must be explicit.

