# RIBASIM-DUMMY-07 stabilization mechanisms

## Purpose

DUMMY-06 qualified a counterexample in which every provisional coupling state
obeys the local management clipping rule and Basin balance, yet undamped
active-set Picard iteration fails to converge to the exact DUMMY-05 solution.

DUMMY-07 tests two bounded repairs without changing any physical or management
equation:

1. under-relax the same active-set Picard map;
2. solve the small active set directly.

The exact DUMMY-05 solution remains the independent reference.

## Under-relaxed map

Let the DUMMY-06 raw active-set map be `F(V)`. Define

```text
G_omega(V) = (1-omega)*V + omega*F(V)
```

with

```text
0 < omega <= 1
```

in this work unit.

### Fixed FULL and ZERO regimes

Inside a FULL or ZERO regime, DUMMY-06 inherits the DUMMY-04 derivative

```text
dF/dV = -lambda
lambda = C*dt/(2A)
```

so the relaxed error factor is

```text
q = dG/dV
  = 1 - omega*(1+lambda)
```

Local convergence therefore requires

```text
|q| < 1
```

or

```text
0 < omega < 2/(1+lambda)
```

The strict inequality matters.

The relaxation that makes the local fixed-regime derivative zero is

```text
omega_star = 1/(1+lambda)
```

Once the correct FULL or ZERO active set is known, one relaxed update with
`omega_star` returns the exact fixed-regime exchange for this linear problem.

This is a local linear result. Active-set identification may still require one
or more preceding updates.

### CURTAILED regime

Inside the interior CURTAILED regime, the raw DUMMY-06 map is constant because
the provisional management clipping enforces

```text
h1 = hmin
```

and therefore returns the exact curtailed exchange independently of the input
guess. Under relaxation,

```text
q_curtailed = 1 - omega
```

relative to that curtailed exchange.

## Stiff DUMMY-06 counterexample revisited

The frozen parameters are

```text
A      = 100 m2
C      = 300 m2/time
dt     = 1
h0     = 1.0 m
hgw    = 0.8 m
hmin   = 0.2 m
R      = 50 m3
lambda = 1.5
```

DUMMY-05 gives the exact FULL solution

```text
U*  = 50 m3
V*  = -6 m3
h1* = 0.56 m
```

while DUMMY-06 undamped Picard cycles.

For this problem,

```text
omega_star = 1/(1+1.5) = 0.4
```

Starting from the same explicit exchange `V0=60 m3`:

```text
V0 = 60  (CURTAILED)
V1 = 12  (FULL)
V2 = -6  (FULL exact fixed point)
V3 = -6
```

The first relaxed update identifies the FULL regime. The second update then
annihilates the fixed-regime linear error.

### Strict stability boundary

For the same problem,

```text
2/(1+lambda) = 0.8
```

At `omega=0.8` the FULL-regime error factor is exactly `q=-1`, not a
contraction. The preregistered sequence is

```text
60, -36, 24, -36, 24, ...
```

After the first transition the iteration remains FULL but alternates with
constant 30 m3 error magnitude around `V*=-6`.

This distinguishes a strict contraction bound from an inclusive heuristic.

## Direct active-set solve

The second route does not iterate the exchange.

It evaluates the same active-set logic used to derive DUMMY-05:

1. solve a coupled FULL trial with `U=R`;
2. accept it if `h1>=hmin`;
3. otherwise solve a coupled ZERO trial with `U=0`;
4. if that trial remains above the physical datum but reaches/crosses
   `hmin`, accept ZERO;
5. otherwise activate `h1=hmin` and solve the management delivery from the
   Basin balance and head-dependent exchange;
6. fail closed if the zero-withdrawal physical solution lies below the datum.

The DUMMY-07 implementation is forbidden to call
`HeadDependentManagementProblem.solve()`. A dense parameter/request matrix
compares its result afterward with the independently retained DUMMY-05 oracle.

## Interpretation

DUMMY-07 can establish three different facts without conflating them:

- DUMMY-06 nonconvergence can be caused by the iteration map rather than by a
  missing physical solution;
- analytically bounded relaxation can recover the exact solution in the
  frozen counterexample without changing physics or management priority;
- for this tiny piecewise-linear problem, direct active-set resolution can
  bypass iterative exchange convergence entirely.

None of those statements determines a production Ribasim-MODFLOW algorithm.
Real networks, nonlinear storage relations, changing groundwater heads,
multiple demands, routing and asynchronous model time integration can change
the problem structure substantially.

## Bounded claim

A successful qualification applies only to the frozen DUMMY-05/DUMMY-06
research system. It does not:

- establish global convergence of relaxed coupling;
- prescribe a production relaxation factor;
- claim direct active-set solving is appropriate for a Ribasim network;
- alter SWAP5, MODFLOW, Ribasim or iMOD Coupler production code.
