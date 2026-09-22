# GC-RZM01 qualification analysis

Date: 2026-09-22  
Status: QUALIFIED RESEARCH ORACLE  
Workflow: 35700927693, job 106658497688

GC-RZM01 closes the first model trap: an explicitly dynamic root store above an
explicit lower-SWAP storage state, with one fixed-interface hydraulic head
`H_c` and exact signed exchange.

All twelve preregistered tests passed without changing an execution gate.

The most important result is not the numerical endpoint. It is the separation
of three notions that were easy to conflate in the earlier one-state dummies.

First, `H_c` remains sufficient to define the **physical interface**. SWAP and
MODFLOW still share one hydraulic head on one geometric plane.

Second, `H_c` is not sufficient to define the **internal SWAP state**. Two
committed columns with the same `H_c` but different root storage produce
different next-window `E_c`. The stronger control also passed: even when total
SWAP water is held equal, changing its vertical distribution changes the
response.

Third, this does not automatically mean that all internal states must cross the
coupler API. In GC-RZM01 the exact finite-window response is affine in trial
`H_c`:

```text
E_c(H_c) = R_* + J_* (H_c-H_*).
```

For fixed linear parameters and window duration, `J_*` is independent of the
committed state. The committed state enters through `R_*`. Thus one scalar
tangent and one intercept are exactly sufficient for the current linear window,
provided their provenance is tied to the immutable committed SWAP origin.

This is a constructive answer to the second programme question:

> interface sufficiency and full-state sufficiency are different properties.

GC-RZM01 supports interface sufficiency without full-state sufficiency.

The result also sharpens the interpretation of a response coefficient. The
canonical one-day tangent is

```text
dE_c/dH_c = -0.14936530755182922.
```

That number is neither `S_r=0.20`, nor `S_l=0.10`, nor `C_v=0.50/day`,
nor `C_c=0.25/day`. It is created by eliminating two internal states over a
finite window. Its value must therefore be interpreted as condensed response,
not renamed physical storage.

The canonical system has two decay times:

```text
tau_fast = 0.1071796769724491 day
tau_slow = 1.492820323027551 day.
```

A one-day coupling window lies between them. That explains why a root-zone
input is partly, but not completely, visible at the lower interface within one
window. It also motivates the next falsification block: systematically move the
coupling window across both internal timescales and test when state elimination
remains a useful scalar condensation.

Finally, the negative controls matter. Deliberately counting lower storage
twice or reversing the MODFLOW interface sign still gives deterministic
algebraic quantities, but fails the physical ledger. Numerical solvability is
therefore again separated from physical correctness.
