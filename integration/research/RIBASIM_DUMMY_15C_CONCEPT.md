# RIBASIM-DUMMY-15C blocked concept: partial irrigation-event realization

> Status: IMPLEMENTED after DUMMY-15B qualification.
>
> This concept was fixed while implementation was blocked. The executable
> oracle was created only after the implementation baseline was rebound to the
> qualified DUMMY-15B authority.

## Why this work unit is needed

The analytical root-bucket experiments deliberately made demand a continuous
water deficit.

The admitted restricted SWAP irrigation route is different.

For the Hupsel TCS1+DCS2 route, irrigation is a **selected event** with:

- a stress trigger;
- an interval gate (dayfix);
- a DVS-dependent event depth;
- a fixed application rate;
- an active-event state;
- an event start and end time.

That means external water scarcity cannot be handled by changing only a
volume.

A coupling must also decide what happens to the irrigation-event state.

## Production authority already identified

Current canonical contains the restricted F-APP07 route:

~~~text
Tred =
  1 - (dry reduction + salinity reduction)
      / potential transpiration
~~~

when potential transpiration is non-negligible.

A stress trigger occurs when

~~~text
Tred < threshold(DVS).
~~~

The trigger is suppressed until

~~~text
dayfix >= minimum_interval_days.
~~~

For the frozen Hupsel route the qualified scheduled event has:

~~~text
depth = 2 cm
rate  = 36 cm/day
duration = 2/36 day.
~~~

When selected, candidate management state resets the interval clock and creates
an active event.

F-APP07 does **not** define what to do if an external allocator can supply only
part of this selected event.

That is the gap DUMMY-15C isolates.

## First analytical case

Use normalized volume units after area conversion.

Selected event request:

~~~text
R_event = 20.
~~~

External physical supply capacity:

~~~text
M_actual = 12.
~~~

Hence:

~~~text
allocation-realization shortfall = 8.
~~~

Before selection:

~~~text
interval gate ready
active_event = false
synthetic dayfix = 7.
~~~

The hydrology and allocation are intentionally frozen.

Only event-realization policy is varied.

## Policy A: atomic event rejection

The selected event is transactionally indivisible.

If full supply is unavailable:

~~~text
supplied = 0
event candidate rejected
management state unchanged.
~~~

The 12 units that could physically have been supplied are deliberately not
used.

This is a management-policy choice, not a hydrological limitation.

No backlog state is created.

At the next opportunity the event may be selected again from the still
authoritative pre-event state.

## Policy B: partial supply, event complete

Use all available water:

~~~text
supplied = 12.
~~~

Commit the event as completed:

~~~text
active_event = false
interval clock reset.
~~~

The missing 8 remain only an allocation-realization diagnostic.

They are **not** carried as event backlog.

This policy therefore tells the management system:

> an irrigation event happened

even though it received less water than requested.

## Policy C: partial supply, residual event active

Again:

~~~text
supplied = 12.
~~~

But now the missing amount becomes explicit management state:

~~~text
event residual = 8.
~~~

Future supply must first complete that residual event.

This introduces management memory independent of current soil-water state.

Current F-APP07 does not contain a residual-volume field, so this is a research
policy, not a claim about production implementation.

## Why B and C are a powerful comparison

Policies B and C can have identical current physical irrigation:

~~~text
U_now = 12.
~~~

The current hydrological state can therefore be identical.

Yet future management demand differs.

Policy B:

~~~text
event residual = 0.
~~~

Policy C:

~~~text
event residual = 8.
~~~

Thus:

~~~text
same hydrology now
!=
same management state
!=
same future demand.
~~~

This is the production-relevant counterpart to the earlier dummy finding that
shortage is not automatically physical state.

## No double memory

A coupling must choose who owns the missing 8.

It may appear as:

- only a diagnostic allocation shortfall;
- explicit event residual management state;
- later hydrologically generated demand;
- or some explicitly defined combination.

It may **not** silently appear in more than one of these places.

For example:

~~~text
8 event residual
+
8 root/soil deficit copied from the same shortage
~~~

would double-count demand memory unless those terms represent independently
derived physical deficits.

## Transaction rule

The event state and supplied water must be one accepted transaction.

Forbidden outcomes include:

### Management commits, water rolls back

~~~text
dayfix reset / event consumed
but irrigation supply not applied.
~~~

This would suppress future irrigation without having supplied the water.

### Water commits, management rolls back

~~~text
12 units enter SWAP
but event state remains as if nothing happened.
~~~

This could allow the same event to be requested again.

Therefore:

> irrigation-event state and realized irrigation transfer must share one
> acceptance boundary.

## Gross versus net irrigation

The real sprinkling path adds another distinction.

External surface-water supply maps first to **gross irrigation**.

With Rutter interception:

~~~text
gross irrigation
  -> canopy interception/storage/evaporation
  -> net irrigation
  -> dynamic soil top.
~~~

DUMMY-15C first isolates event-state policy.

It does not yet replace the analytical transfer with the complete Rutter
ledger.

That mapping belongs to the later real-model authority/substitution stages.

## Why partial rate is not silently assumed

The admitted Hupsel process has a fixed selected depth and rate.

If only part of the water is available, several implementation ideas are
possible:

- reduce rate;
- shorten duration;
- pause and resume;
- reject the event;
- reschedule the event.

These are **different management semantics**.

None may be introduced merely as a numerical convenience.

## Qualification target

The DUMMY-15C implementation tests for every policy:

1. physical water supplied equals the policy's declared supplied amount;
2. allocated-but-unsupplied water never enters a water ledger;
3. management-state transition is explicit;
4. future event demand follows only declared state;
5. event state and supplied water commit or roll back together;
6. no hidden backlog exists outside declared state.

## Production boundary

DUMMY-15C will not decide which policy production SWAP-Ribasim coupling should
use.

Its role is to expose the consequences of each policy before a production
contract is chosen.
