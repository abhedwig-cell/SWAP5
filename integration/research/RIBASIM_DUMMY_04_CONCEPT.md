# RIBASIM-DUMMY-04 linear iteration mechanism

## Question

DUMMY-03 established that a Basin-groundwater exchange evaluated from the
committed Basin level can become inconsistent with the Basin level produced by
that same coupling window.

DUMMY-04 isolates the numerical mechanism before management shortage and
production coupling are reintroduced:

> Under one frozen trapezoidal exchange closure, when does simple fixed-point
> iteration converge, oscillate or diverge?

The result is deliberately limited to this linear surrogate.

## Frozen discrete problem

Let:

- `A` be constant Basin surface area [m2];
- `C` be exchange conductance [m2/time];
- `dt` be the coupling-window duration [time];
- `h0` be Basin level at the start of the window [m];
- `h1` be Basin level at the end of the window [m];
- `hgw` be groundwater head, fixed within the window [m];
- `U` be managed withdrawal, frozen within this numerical sub-experiment [m3];
- `V` be signed groundwater exchange [m3], positive for Basin to groundwater.

The temporal exchange closure is fixed as

```text
V = C * dt * (((h0 + h1) / 2) - hgw)
```

and the Basin water balance is

```text
h1 = h0 - (U + V) / A
```

Substitution gives

```text
V = C*dt*(h0-hgw) - C*dt*(U+V)/(2A)
```

Define

```text
lambda = C*dt/(2A)
```

Then

```text
(1 + lambda) V = C*dt*(h0-hgw) - lambda*U
```

and the exact fixed point is

```text
V* = [C*dt*(h0-hgw) - lambda*U] / (1 + lambda)
```

## Picard iteration

Use the exchange estimate from iteration n to calculate an end level, then
re-evaluate the trapezoidal exchange:

```text
V_(n+1) = F(V_n)
```

For the linear problem,

```text
F(V) = C*dt*(h0-hgw) - lambda*U - lambda*V
```

so for the error `e_n = V_n - V*`,

```text
e_(n+1) = -lambda * e_n
```

This provides an exact diagnostic, with no empirically chosen convergence
tolerance:

- `lambda < 1`: alternating geometric convergence;
- `lambda = 1`: equal-magnitude alternation unless initialized exactly at the
  fixed point;
- `lambda > 1`: alternating growth of the error magnitude.

The sign reversal is as relevant as the magnitude. A strongly coupled window
can oscillate between over- and under-estimated exchange even though every
individual model evaluation is deterministic.

## Explicit and one-corrector estimates

The explicit start-level estimate is

```text
V_exp = C*dt*(h0-hgw)
```

One corrector is one application of the Picard map:

```text
V_corr = F(V_exp)
```

For `lambda < 1`, the corrector error magnitude is exactly `lambda` times
the explicit error magnitude. It therefore improves the estimate but is not
generally exact.

This work unit does not decide that one corrector is sufficient. It only
establishes the exact error propagation for the frozen problem.

## Timestep implication

Because

```text
lambda = C*dt/(2A)
```

the same physical conductance can move between convergent and divergent Picard
regimes solely through the coupling-window duration.

For example, with `A=100 m2` and `C=300 m2/time`:

```text
dt = 1.0 -> lambda = 1.5
dt = 0.4 -> lambda = 0.6
```

Simple Picard iteration therefore diverges in the first frozen problem and
converges in the second.

This is not a universal MODFLOW-Ribasim timestep criterion. The formula follows
from the constant-area, fixed-groundwater-head, linear-conductance,
trapezoidal-exchange problem defined above.

## Role of management withdrawal

`U` shifts the fixed point:

```text
V* = [C*dt*(h0-hgw) - lambda*U] / (1 + lambda)
```

but does not change the derivative of the Picard map:

```text
dF/dV = -lambda
```

Hence, under this frozen linear problem, management demand changes the coupled
solution but not the local Picard error factor.

DUMMY-04 deliberately freezes `U`. Shortage clipping and the DUMMY-02
hydrology-before-management rule are not part of this qualification. They can
be reintroduced only after this numerical mechanism is closed.

## Bounded claim

A successful DUMMY-04 qualification establishes an exact analytical and
implemented result for this research surrogate only:

```text
Picard error factor = -C*dt/(2A)
```

It does not establish:

- a universal stability threshold for real Ribasim-MODFLOW coupling;
- a correct production timestep;
- that trapezoidal exchange is the uniquely correct temporal closure;
- that Picard is the preferred production coupling algorithm;
- any production change to SWAP5, MODFLOW, Ribasim or iMOD Coupler.
