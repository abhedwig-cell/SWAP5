# Coupled residual and Schur-complement interpretation

Date: 2026-09-21
Status: RESEARCH MATHEMATICAL SYNTHESIS, production read-only

## 1. Coupled unknowns

Use two interface unknowns:

```
H  shared groundwater / phreatic head
q  exchange flux, positive outward from SWAP and into groundwater
```

The physical coupled problem may be written as:

```
F_gw(H,q) = 0
q - q_swap(H) = 0
```

where:

- `F_gw` is the groundwater balance after all groundwater-owned processes
  and storage are assembled;
- `q_swap(H)` is the accepted prescribed-head SWAP corrector response from
  the immutable SWAP origin.

The accepted interface ledger integrates `q_swap`, not a predictor surrogate.

## 2. Exact coupled Jacobian

Let:

```
A   = partial F_gw / partial H
B   = partial F_gw / partial q
J_R = d q_swap / dH
```

The block Newton matrix is:

```
[ A     B ] [dH] = -[F_gw]
[-J_R   1 ] [dq]   -[q-q_swap]
```

Eliminating `dq` gives the exact head Schur complement:

```
J_eff = A + B*J_R.
```

For the common scalar sign convention

```
F_gw(H,q) = A*(H-H0) - L - q
```

we have `B=-1`, hence:

```
J_eff = A - J_R.
```

This is the derivative relevant to a Newton solve of the coupled physical
residual.

## 3. Shared-storage limiting case

Suppose one physical shared-head system has storage partitioned consistently:

```
S_g  groundwater-owned storage
S_s  SWAP-owned storage
```

For one backward-Euler window:

```
A   = S_g / dt
J_R = -S_s / dt
```

because a higher prescribed terminal head requires more water to remain stored
in the SWAP column and therefore reduces outward bottom exchange.

Then:

```
J_eff
  = A - J_R
  = S_g/dt + S_s/dt
  = (S_g+S_s)/dt.
```

The combined physical storage appears exactly once.

This is the differential form of the DSW02 storage-partition invariance.

## 4. Duplicate-storage signature

If MODFLOW already owns the full physical shared storage `S` and the SWAP
corrector independently contains the same storage response:

```
A   = S/dt
J_R = -S/dt
```

then:

```
J_eff = 2S/dt.
```

The coupled system behaves as if the physical storage were doubled.

This is not a numerical accident. It is a domain/storage-ownership error.

Therefore storage ownership must be defined before deciding which derivatives
belong in the coupled equations.

## 5. Affine iteration response

The current application route does not insert the full nonlinear
`q_swap(H)` directly into MODFLOW. At coupling iteration `k`, it uses an
affine response:

```
q_iter(H)
  = q_swap(H_k) + s*(H-H_k)
```

after reanchoring at the measured corrector point.

The slope `s` is an iteration-response policy.

For the scalar groundwater equation, solving the affine subproblem gives an
effective matrix:

```
A - s.
```

The exact coupled matrix would be:

```
A - J_R.
```

Thus `s=J_R` is the exact Newton slope for this linear scalar model, but it is
not the only slope that can reach the correct fixed point.

## 6. Error propagation for a linear physical corrector

Let the physical corrector be linear:

```
q_swap(H) = q_* + j*(H-H_*).
```

Let `H_*` be the exact coupled root.

The reanchor-and-resolve iteration obeys:

```
e_{k+1}
  = ((j-s)/(A-s)) e_k,
```

where:

```
e_k = H_k-H_*.
```

Therefore:

```
rho = (j-s)/(A-s)
```

is the scalar coupling-iteration factor.

Consequences:

- `s=j`: one-step exact for the linear case;
- `s=0`: Picard/intercept-only iteration;
- `|rho|<1`: convergent;
- `rho<0`: alternating convergence;
- `|rho|=1`: neutral cycle;
- `|rho|>1`: divergence;
- `s=A`: affine groundwater subproblem becomes singular.

DSW21 is the live MODFLOW oracle for this identity.

## 7. Why a numerically useful slope need not be a physical coefficient

The fixed point is defined by:

```
F_gw(H,q_swap(H)) = 0.
```

Any reanchored affine response satisfies:

```
q_iter(H_k) = q_swap(H_k).
```

Changing `s` changes the route to the root, not the root itself, provided:

- every corrector point is valid;
- the iteration converges;
- the final corrector residual is closed;
- storage ownership in the physical equations is correct.

MAP04 and MAP05A are real-SWAP examples where different nonzero slope policies
reach essentially the same accepted physics.

MAP05/MAP06 show why route choice still matters: different slopes visit
different heads, and the current B3 prescribed-head corrector has a fragmented
numerical admissibility set.

## 8. Where production +u/dt sits

F-GC30/F-GC40 define:

```
s_policy = +u_A/dt.
```

MAP07 establishes that this is the partial derivative of the historical affine
`q_u` construction at fixed predictor `qbot` and `u_A`.

It is not generally:

- the total derivative of `q_u` along neighboring predictor states;
- the physical corrector derivative `J_R`;
- a physical q-link conductance;
- universal physical storage.

In the simple MAP03 fixture:

```
u_A ~= J_S
J_R ~= -u_A
```

so the production policy slope and physical corrector slope have opposite
sign.

This does not by itself make the production iteration invalid. It means its
role is preconditioner / iteration response rather than automatically the
exact physical Schur derivative.

## 9. Relation to shared-state literature

The shared-state SIMGRO formulation uses one shared state and a combined
storage relationship. The Schur result above is the local differential form
of the same bookkeeping requirement:

```
storage represented in subsystem A
+ storage represented in subsystem B
= physical total storage
```

with no overlap and no missing volume.

The current iMOD Coupler documentation provides a concrete implementation
example where MetaSWAP sets storage in coupled MODFLOW cells rather than acting
only as a recharge generator.

## 10. Research decision rule

Before changing any production coupling slope, answer separately:

1. **Physical domain ownership**
   Which storage belongs to SWAP, MODFLOW, or a genuinely overlapping shared
   state?

2. **Physical coupled residual**
   What equations define the accepted `(H,q)` pair?

3. **Exact residual derivative**
   Which derivative would appear in the Schur complement of those equations?

4. **Iteration response**
   Which approximate slope gives robust convergence through the actual
   corrector admissibility domain?

5. **Acceptance**
   Which independent mass, residual and transaction gates certify the final
   state?

Only after those five questions agree is a production reformulation justified.
