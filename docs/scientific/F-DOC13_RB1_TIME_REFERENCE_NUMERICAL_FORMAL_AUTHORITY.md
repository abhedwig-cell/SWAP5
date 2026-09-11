# F-DOC13 — RB1 TIME-REFERENCE Restricted Numerical/Formal T0–T7 Authority

## Purpose

F-DOC13 resolves the bounded T0–T7 numerical/formal authority gap for the single `NUMERICAL_METHOD` capability identified by F-DOC11: `RB1-TIME-REFERENCE`.

The workunit is documentation and traceability only. It does not change source code, reference data, physics, solver implementation, scientific tolerances, hard mass criteria, temporal acceptance behaviour or performance policy. The machine-readable authority is `docs/scientific/registries/rb1-time-reference-numerical-formal-authority.json`.

The governing principle is deliberately narrow: document only numerical semantics already established by the F-SI24 → F-VQ30 → F-SI25 → F-SI26 → F-VQ34 lineage and already present in frozen RB1. Do not convert finite nonlinear transfer evidence into a general nonlinear error theorem and do not invent an application accuracy budget.

## Controlled authority chain

### F-SI24: analytic basis

F-SI24 derived the fixed stiffness-aware construction for the constant linear dissipative semi-discrete problem

`M u_dot + A u = 0`,

with constant symmetric positive-definite `M`, constant symmetric positive-semidefinite `A`, and backward Euler over `dt > 0`.

For that exact-linear scope it defines

- `e_raw = 0.5 dt (u_dot_{n+1} - u_dot_n)`;
- `J_BE delta = (M/dt) e_raw`;
- `B_M = min(||e_raw||_M, 2 ||delta||_M)`;
- `B_inf = B_M / sqrt(m_min)` for the qualified positive-diagonal `M` construction.

F-SI24 proves the exact-linear M-norm bound and its head-infinity conversion within that stated scope. It explicitly does **not** prove a general nonlinear Richards true-error bound.

### F-VQ30: independent held-out transfer qualification

F-VQ30 independently reproduced the exact manufactured linear candidate and qualified transfer of the fixed indicator to a disjoint nonlinear B1.10 matrix as finite-comparator-consistent evidence. It explicitly retained the nonclaim that `B_inf` is not a general nonlinear true-error upper bound.

That distinction is essential for F-DOC13. The exact-linear theorem is formal numerical authority; the nonlinear result is transfer/consistency evidence only.

### F-SI25: production solver-owned indicator seam

F-SI25 materialised the indicator behind the soil-water solver interface. Accepted-state operator work remains solver-owned and temporary arrays remain invocation-local scratch. The principal Richards state and flux solution is not replaced by the indicator. Unsupported solver/physics combinations return indicator-unavailable and fail closed.

### F-SI26 and F-VQ34: normalization and policy binding

F-SI26 introduced the dimensionally explicit normalization

`C_h = B_inf / H_budget`.

`H_budget` has no default. It must be supplied explicitly, finite and positive, in the Richards head unit. F-VQ34 then independently qualified the remediated production policy binding on a fresh matrix without selecting any numerical application budget.

F-VQ34 also qualified that missing/invalid budget, unavailable indicator and missing history fail closed; hard mass rejection precedes temporal-certificate acceptance; bounded retry/rollback preserves committed state; and no monotonic improvement of `C_h` under shorter `dt` is assumed.

### F-DOC08: bounded equation-to-test graph

F-DOC08 already connected the qualified relations to tests and release replay. Its bounded T11 graph is complete for the restricted temporal acceptance semantics, while universal application accuracy and T12 remain open.

## T0–T7 disposition

### T0 — not applicable

`RB1-TIME-REFERENCE` is a numerical control capability, not an independently represented physical phenomenon. Physical phenomena belong to the process capabilities whose candidate states are being advanced.

### T1 — restricted numerical rationale resolved

The numerical rationale is controlled by the exact-linear backward-Euler error-bound derivation and independent reproduction, combined with the later normalized certificate and independently qualified fail-closed acceptance semantics.

The scope boundary is hard: the exact true-error theorem is the constant-linear dissipative semi-discrete case only. Nonlinear B1.10 evidence does not generalize that theorem.

### T2 — restricted conceptual model resolved

A converged Richards candidate is observed without changing the principal solution. Previous accepted right-derivative history and the current endpoint derivative feed a model-owned indicator. `B_inf` is normalized only by an explicitly supplied `H_budget`. Missing prerequisites make the certificate unavailable rather than fabricating a value or bootstrap.

### T3 — formal quantities resolved

Within the admitted construction:

- current endpoint derivative representation is `(u_{n+1}-u_n)/dt`;
- `e_raw = 0.5 dt (u_dot_{n+1}-u_dot_n)`;
- `J_BE delta = (M/dt)e_raw`;
- `B_M = min(||e_raw||_M, 2||delta||_M)`;
- `B_inf = B_M/sqrt(m_min)` in the qualified positive-diagonal construction;
- `C_h = B_inf/H_budget`;
- `H_budget` must be supplied, finite and `>0`;
- certificate validity additionally requires qualified history and an available finite nonnegative indicator;
- model-certificate acceptance is `C_h <= 1`, after the hard mass gate.

The fixed factor 2 is inherited from the exact-linear derivation, not fitted from nonlinear outcomes.

## T4 — restricted SWAP formulation resolved

The admitted production envelope remains the reference Richards binding qualified upstream: explicit fixed-flux top boundary, bottom mode 5, no active macropore operator, no active root-sink provider, admitted B1.10 head-independent source/sink semantics, `conductivity_implicit_mode=0`, and `conductivity_mean_method=1`.

Unsupported routes return indicator-unavailable. F-DOC13 does not broaden this physics envelope.

## T5 — continuous/semi-discrete numerical basis resolved, restricted

The controlled continuous/semi-discrete basis for the exact theorem is `M u_dot + A u = 0` with constant `M` and `A` as specified by F-SI24. Backward Euler supplies the discrete endpoint state and derivative relation from which the indicator is built.

This is sufficient to document the continuous temporal quantities underlying the exact-linear theorem. It is **not** evidence that the production nonlinear Richards indicator is a rigorous true-error upper bound under state-dependent operators. That boundary remains explicit.

## T6 — time discretisation resolved, restricted

The reference route advances generic caller-supplied model time with `dt=t1-t0>0`; it has no day or midnight dependency. The indicator consumes qualified previous accepted derivative history and the current candidate endpoint derivative. On temporal rejection, transactional retry reduces the attempted interval according to the admitted retry policy.

No theorem states that shorter `dt` must monotonically reduce `C_h`. No coupling-window accuracy budget is inferred from this route.

## T7 — acceptance/retry method resolved, restricted

For model-certificate mode the transaction route is:

1. start from the committed checkpoint and attempt the candidate interval;
2. reject and retry if the solver fails;
3. evaluate hard mass balance and reject/retry on mass failure;
4. require an available finite nonnegative temporal certificate;
5. accept temporally only when `C_h <= 1`;
6. otherwise rollback and retry with bounded retry count;
7. commit the candidate state only after all gates pass.

The certificate cannot override mass failure. There is no default `H_budget` and no no-history bootstrap.

## What F-DOC13 closes

Within the fixed RB1 restricted TIME-REFERENCE capability, all T0–T7 tiers now have an explicit controlled disposition. This closes the `NUMERICAL_METHOD` portion of the F-DOC11 T0–T7 decomposition.

It does not make `RB1-TIME-REFERENCE` `FULLY_TRACED`. T12 application validation remains open, application-specific budget selection remains external, and any remaining T8–T10 or broader graph obligations stay governed by the existing traceability registries.

## Hard nonclaims

F-DOC13 does not:

- select, recommend or qualify a numeric `H_budget` for any application;
- establish a universal temporal tolerance or groundwater-head accuracy budget;
- promote `B_inf` or `C_h` to a general nonlinear true-error bound;
- claim shorter-step monotonicity;
- add bootstrap, arbitrary restart-history reconstruction, forcing/event/topology-discontinuity or coupling-window continuation scope;
- change production source, reference data, physics, solver, scientific tolerances, hard mass criteria, temporal acceptance or performance policy;
- release groundwater coupling or close any application-level total error budget;
- promote any capability to `FULLY_TRACED`, Status A readiness, Status A compliance or Status AA compliance;
- reopen frozen RB1 scientific, qualification or release authority.
