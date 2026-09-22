# GC-RZM04 qualification analysis

Date: 2026-09-22  
Decision: **QUALIFIED_MINIMAL_NONLINEAR_RESPONSE_FALSIFICATION**

Workflow 35706139759 is green, including RZM01-RZM03 regressions. RZM04 passed
7/7 gates.

Only the internal vertical conductance was made state dependent. That was
enough to produce a finite-window second difference of
`-4.1189106897952452e-4 m` across the preregistered H_c probe. The exact
affine response property of RZM01 is therefore not structurally robust to this
minimal nonlinearity.

The local response tangent also changed with committed internal state:
`-0.14832612843183748` versus `-0.1500952263014648 m/m`, a difference of
about `1.77e-3 m/m`. Thus the linear result that one state-independent
finite-window tangent characterizes the response does not survive.

What did survive is equally important: the fixed physical interface is still
described by one H_c, mass ownership is unchanged, upward/downward exchange
still follows one signed law, and repeated trials from one immutable committed
origin are identical.

The failed predecessor run was numerical test design, not model failure. Its
RK4 solutions were already at roughly 1e-15 relative to the fine reference, so
strict monotonic error decrease was below the floating-point floor. The repair
retained the preregistered 2e-10 accuracy bound.

## Decision

Phase F is closed. The next controlled addition is management semantics, not
more hydraulic complexity. RZM05 will bind irrigation demand to committed root
storage using the already qualified Ribasim root-zone interpretation. Shortage
must remain diagnostic rather than becoming hidden persistent water state.
