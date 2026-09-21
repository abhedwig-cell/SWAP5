# RIBASIM-DUMMY-15D blocked concept: canopy interception ledger

> Status: BLOCKED pending DUMMY-15C qualification.
>
> No implementation or tests are authorized yet.

## Why this work unit exists

The earlier analytical irrigation transfer treated supplied irrigation as if it
moved directly from the surface-water source into the root/soil store.

The admitted restricted SWAP sprinkling path is more detailed:

~~~text
surface-water source withdrawal
  -> gross irrigation
  -> canopy interception
  -> net soil irrigation
~~~

The Rutter process also carries canopy storage and interception evaporation.

Therefore one scalar irrigation transfer is not enough for real-model
substitution.

## Analytical stores

DUMMY-15D adds an explicit canopy store C to the existing analytical stores:

~~~text
surface source storage S_s
canopy storage C
root/soil storage W
groundwater storage S_g.
~~~

## Analytical transfers

Use:

~~~text
G   gross supplied irrigation withdrawn from the surface source
I   intercepted part entering canopy storage
N   net irrigation reaching the soil top
E_i interception evaporation
V   reciprocal surface-groundwater exchange.
~~~

For irrigation-only interception:

~~~text
G = N + I.
~~~

Canopy state evolves as:

~~~text
Delta C = I - E_i.
~~~

The remaining component ledgers are:

~~~text
Delta S_s = -G - V
Delta W   = +N
Delta S_g = +V.
~~~

Adding all four stores:

~~~text
Delta(S_s + C + W + S_g)
  = -E_i.
~~~

Thus the only external loss in this first-stage full-system ledger is
interception evaporation.

## Canonical case

Start with:

~~~text
S_s = 100
C   = 0
W   = 40
S_g = 50.
~~~

Prescribe:

~~~text
G   = 20
I   = 5
N   = 15
E_i = 2
V   = 4.
~~~

These satisfy:

~~~text
G = N + I = 20.
~~~

The endpoint is:

~~~text
S_s1 = 100 - 20 - 4 = 76
C1   = 0 + 5 - 2    = 3
W1   = 40 + 15      = 55
S_g1 = 50 + 4       = 54.
~~~

Initial total:

~~~text
190.
~~~

Final total:

~~~text
188.
~~~

Therefore:

~~~text
Delta total = -2 = -E_i.
~~~

The groundwater exchange still cancels exactly.

## Why gross cannot be used as soil input

Suppose the model withdraws:

~~~text
G = 20
~~~

from the surface source and also stores:

~~~text
I-E_i = 3
~~~

in the canopy, but applies the full 20 to the soil.

The intercepted part has then been represented twice.

The correct soil input is:

~~~text
N = 15.
~~~

## Why net cannot be used as source withdrawal

The opposite error is equally serious.

If the surface source loses only:

~~~text
N = 15
~~~

while the canopy still receives:

~~~text
I = 5,
~~~

the intercepted water has no source.

Therefore:

> Ribasim/source withdrawal must bind to gross supplied irrigation, while SWAP
> soil-top irrigation binds to net irrigation after interception.

These are two distinct coupling quantities.

## System-boundary dependence

If canopy storage is inside the represented system:

~~~text
Delta total = -E_i.
~~~

If canopy state is excluded, the represented stores are only:

~~~text
surface + root + groundwater.
~~~

Then:

~~~text
Delta represented total
  = -(E_i + Delta C).
~~~

For the canonical case:

~~~text
-(2+3) = -5.
~~~

An apparent 3-unit mass defect appears if canopy storage is omitted but only
interception evaporation is counted as a boundary loss.

That is not a numerical error.

It is a system-boundary error.

## Relation to real Rutter

Current canonical Rutter provides:

~~~text
accepted canopy_storage_cm
reservoir_inflow
reservoir_outflow
net_surface_irrigation
candidate canopy_storage.
~~~

For the later real-model bridge:

~~~text
I   <-> integrated reservoir inflow attributable to irrigation
E_i <-> integrated reservoir outflow / interception evaporation
N   <-> integrated net_surface_irrigation
Delta C <-> candidate - accepted canopy storage.
~~~

The exact attribution of reservoir inflow between rain and irrigation must be
handled explicitly when rainfall is later added.

The first DUMMY-15D stage excludes rainfall so the identity remains
unambiguous.

## Transaction implication

Canopy candidate state must be accepted or rejected consistently with:

- gross external supply;
- irrigation-event management state;
- soil/kernel candidate state.

Committing net soil irrigation while rolling back canopy state, or vice versa,
would violate the water ledger.

This reinforces the DUMMY-15C requirement for one accepted irrigation
transaction.

## Qualification target

A future DUMMY-15D implementation must independently prove:

1. G=N+I;
2. canopy storage balance;
3. full four-store balance;
4. system-boundary transformation when canopy is excluded;
5. exact cancellation of V;
6. failure of the two preregistered gross/net misbinding cases.

## Boundary

DUMMY-15D does not reproduce the nonlinear/event-limited Rutter algorithm.

It first qualifies the transfer and system-boundary algebra needed to interpret
a later real Rutter substitution.
