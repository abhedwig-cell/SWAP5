# GC-RZM02 qualification analysis

Date: 2026-09-22  
Decision: QUALIFIED_FORCING_ORDER_AND_TIMESCALE_CONDENSATION  
Workflow: 35701697622

RZM02 closes the first explicit path-memory and timescale block on top of the
qualified two-state oracle.

The canonical forcing-order pair receives exactly the same 0.010 m root input.
It does not reach the same accepted state:

```text
early input:
  W_r,end = 0.10479863076424234 m
  h_l,end = 8.017491004024908 m
  E_c     = 0.003452268833266857 m

late input:
  W_r,end = 0.10715059383990400 m
  h_l,end = 8.018400792708118 m
  E_c     = 0.0010093268892842205 m.
```

The balances close in both cases. The difference is not missing water. Early
water has had more time to traverse the internal vertical states and leave
through the fixed plane; late water remains more strongly stored internally.

The conductance scaling experiment adds an important qualification. Order
sensitivity is small in the very slow control, much larger at the canonical
intermediate scale, and small again in the very fast control. The experiment
does not locate a mathematical maximum. It does establish that "slower means
more memory" is too crude. Memory becomes observable when the forcing schedule,
internal relaxation and observation/coupling window interact.

The response-window sweep gives a second direct result. Using
`u(T)=-dE_c/dH_c` only as local research notation:

```text
T=0.01 d  -> u=0.0024695136748933825
T=1.00 d  -> u=0.14936530755182925
T=10.0 d  -> u=0.29963723589847224.
```

The physical root and lower storage coefficients remain 0.20 and 0.10
throughout. The window-dependent coefficient therefore cannot be identified
with either physical storage. In the long-window limit it approaches their sum
because both internal storage coordinates have enough time to respond to a
permanent shift of the fixed boundary head.

The boundary-order test is equally important for coupling semantics. Two
half-window head trajectories have the same mean 8.0 m:

```text
7.95 -> 8.05 m  gives E_c=-0.0014699769222886244 m
8.05 -> 7.95 m  gives E_c=+0.0014699769222885038 m.
```

The constant 8.0 m whole-window control gives zero. Thus exact substep
equivalence requires the same boundary trajectory. A mean or endpoint head is
not in general an exact summary of a time-varying boundary condition.

This does not force internal SWAP states into the coupler. It instead sharpens
what a condensed coupling response must represent. For the present linear
constant-head window, one affine response remains exact. If the physical
interface head varies materially within that window, either the trajectory must
be resolved, the window shortened, or a richer temporal response must be used.

Finally, fast root-to-lower equilibration recovers a one-state physical
structure with combined storage `S_r+S_l`. The exact continuous-time response
and the earlier NH01 implicit-Euler one-step response are deliberately not
identical. This is a numerical-temporal distinction, not a disagreement about
the fixed-interface physics.
