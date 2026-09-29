# F-PE-TIMEINT15 P1 preregistration addendum — smooth physical flux quadrature

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_P1_RESULTS`

Parent:

`F-PE-TIMEINT15_PREREGISTRATION.md`

P0 authority before this addendum:

- Actions run `36520159979`;
- P0 smooth mechanism passes;
- 4/4 ladders complete;
- median refined top-head order about 1.93;
- physical interval and cumulative ledgers remain roundoff-scale;
- median work per step equals the TIMEINT13 extrapolated-K BDF2 comparator.

## P1 forcing

Use a smooth prescribed infiltration rate:

`q(t) = q_bar + q_amp sin(2*pi*t/T)`

with frozen values:

- `q_bar = 3.0 cm/day`;
- `q_amp = 1.0 cm/day`;
- `T = 0.060 day`;
- measured horizon = `0.040 day`.

Thus q remains positive and no top-boundary regime switch is possible.

Materials:

- B01;
- O05.

Measured dt ladder:

- 0.010 d;
- 0.005 d;
- 0.0025 d;
- 0.00125 d.

## History bootstrap

For each dt, create one accepted BE/KLAG prehistory step immediately before the measured interval.

The prehistory step exists only to seed accepted conductivity history.

It is excluded from:

- measured cumulative physical input;
- quadrature error;
- P1 convergence-order calculation.

The measured interval begins at t=0 and uses TRAP_KPRED from its first measured step.

## Endpoint forcing semantics

For measured interval [t_n,t_(n+1)]:

- accepted-origin operator uses physical rate q(t_n);
- endpoint candidate operator uses physical rate q(t_(n+1));
- physical published top-input mass is:
  `I_n = 0.5*h*(q(t_n)+q(t_(n+1)))`.

No previous-interval mass enters I_n.

## Analytical authority

Exact cumulative top input over [0,H]:

`I_exact(H)=q_bar*H + q_amp*T/(2*pi)*(1-cos(2*pi*H/T))`.

P1 records:

- cumulative trapezoidal input;
- exact analytical cumulative input;
- absolute quadrature error;
- physical storage change;
- per-step physical ledger against trapezoidal input;
- cumulative physical ledger.

## Frozen P1 gates

For both materials:

1. all four measured ladders complete;
2. max per-step physical ledger <=5e-8 cm;
3. cumulative physical ledger <=5e-8 cm;
4. observed refined quadrature order using dt=0.005, 0.0025, 0.00125 d >=1.8;
5. median refined quadrature order across B01/O05 >=1.9;
6. no conductivity clamps;
7. no alternative-solver calls;
8. no nonfinite state.

The exact analytical input is an accuracy oracle. It is not substituted into the model ledger.

If P1 passes, dynamic-top P2 may be preregistered separately.
