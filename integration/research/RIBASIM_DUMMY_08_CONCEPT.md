# RIBASIM-DUMMY-08 temporal partition and management-event timing

## Purpose

DUMMY-05 through DUMMY-07 solve one coupling window consistently. DUMMY-08 asks
whether repeating such accepted windows yields the same hydrological-management
trajectory when the coupling horizon is partitioned differently.

The answer need not be yes even when every window closes mass exactly.

This work unit isolates time resolution of the management decision from
water-balance correctness.

## Discrete multi-window contract

For window n with duration `dt_n`:

1. start from the committed Basin level `h_n`;
2. convert one exogenous request rate `r` to a requested volume

```text
R_n = r * dt_n
```

3. solve the window with the qualified DUMMY-07 direct active-set route;
4. commit the accepted end level as `h_(n+1)`;
5. do not carry previous shortage into the next request.

With positive exchange `V_n` defined from Basin to groundwater, cumulative
balance over N windows is

```text
A*(h_0-h_N) = sum(U_n) + sum(V_n)
```

No external surface-water inflow is included in DUMMY-08.

## Independent continuous reference

For the restricted constant-parameter reference domain,

```text
A dh/dt = -r - C(h-hgw)
```

while management demand is active.

Define

```text
h_eq = hgw - r/C
```

Then

```text
h(t) = h_eq + (h0-h_eq) exp(-(C/A)t)
```

If this trajectory reaches the management minimum level `hmin`, the
management request is shut off at the event time

```text
t_hit =
  -(A/C) ln[(hmin-h_eq)/(h0-h_eq)]
```

for the preregistered domain `hgw < hmin < h0`.

After the event, management delivery is zero but physical exchange continues:

```text
A dh/dt = -C(h-hgw)
```

so

```text
h(t) =
  hgw + (hmin-hgw) exp[-(C/A)(t-t_hit)]
```

The continuous cumulative management delivery is

```text
U = r * t_hit
```

when the event occurs inside the horizon.

Cumulative physical exchange follows independently from mass balance:

```text
V = A*(h0-h(T)) - U
```

This reference is not a general Ribasim-MODFLOW continuous model. It exists
only for the frozen one-Basin, constant-head, constant-rate experiment.

## Canonical event case

Use

```text
A       = 100 m2
C       = 50 m2/time
h0      = 1.0 m
hgw     = 0.0 m
hmin    = 0.4 m
r       = 40 m3/time
T       = 1 time
```

### One coupling window

The exact DUMMY-05/DUMMY-07 per-window solution is CURTAILED:

```text
U = 25 m3
V = 35 m3
h1 = 0.40 m
```

The management withdrawal is spread over the whole coarse window in such a way
that the accepted endpoint lands exactly on the management threshold.

### Two half-windows

For `dt=0.5`:

First half:

```text
regime = FULL
U1 = 20 m3
V1 = 20 m3
h1 = 0.60 m
```

Second half:

```text
regime = CURTAILED
U2 = 7.5 m3
V2 = 12.5 m3
h2 = 0.40 m
```

Hence

```text
sum(U) = 27.5 m3
sum(V) = 32.5 m3
```

The final level is unchanged from the coarse case, but allocation between
management and physical exchange is already different.

### Continuous event reference

For the same constant parameters,

```text
h_eq = -0.8 m
t_hit = 2 ln(1.5) ~= 0.81093
```

so management runs at the full rate until about 81% of the horizon:

```text
U_cont = 40 * 2 ln(1.5) ~= 32.44 m3
```

After management shuts off, infiltration continues. Therefore

```text
h(T) =
  0.4 exp[-0.5(1 - 2 ln(1.5))]
  ~= 0.364 m
```

The management threshold is crossed by physical hydrology after management has
already stopped. It is not a physical floor.

## Why uniform refinement is not monotonically ordered

The first preregistration draft expected every timestep halving to decrease the
event error monotonically. Prequalification analysis falsified that assumption
before DUMMY-08 tests or qualification existed.

The reason is active-set event alignment.

For one uniform grid, a window can enter CURTAILED and solve a partial
management delivery that lands exactly on `hmin`. For another grid, a full
window can end sufficiently close to `hmin` that the next window is already
classified ZERO. The discrete shutoff time therefore moves relative to the
continuous event when the grid changes.

Consequently:

- cumulative balance can remain exact for every partition;
- endpoint and delivered-volume error can show small sawtooth changes under
  refinement;
- sufficiently fine partitions can still approach the continuous event
  solution overall.

DUMMY-08 explicitly qualifies this event-grid jitter rather than hiding it
behind a monotonic-convergence claim.

## Key interpretation

The management minimum level has two distinct meanings depending on temporal
resolution:

- within a coupling window it is an active management constraint;
- after managed delivery becomes zero, it has no authority to stop physical
  exchange.

A coarse window can smear the management curtailment through time and end at
the threshold. A finer or continuous representation can instead deliver more
water early, stop management at the event, and subsequently move physically
below the threshold.

That is a decision-timing effect, not a mass-balance defect.

## Bounded claim

DUMMY-08 does not introduce:

- shortage backlog;
- adaptive SWAP demand;
- varying groundwater head;
- Ribasim routing;
- dry-boundary physics;
- a production coupling timestep criterion.

It establishes only the temporal-partition behavior of the frozen qualified
dummy system.
