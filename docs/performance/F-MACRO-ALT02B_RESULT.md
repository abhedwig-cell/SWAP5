# F-MACRO-ALT02B — minimal sufficient sorption-history state

Date: 2026-09-30

Status: `QUALIFIED_ANALYTICAL_REDUCTION_RESULT`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Starting point

F-MACRO-ALT02 established that exact preservation of the current SWAP Philip-sorptivity absorption semantics cannot be memoryless.

The current formulation carries source-backed event information through variables including:

- `SorpDmCp`;
- `ThtSrpRefDmCp`;
- `TimAbsCumDmCp`;
- `FlEndSrpEvt`.

The official theory expresses cumulative lateral absorption schematically as:

```text
I_abs(t) = G(geometry) * S_P(theta0) * sqrt(t - t0)
```

where:

- `theta0` is matrix water content at first contact;
- `t0` is first-contact time;
- `S_P` is fixed from the event-start condition for that sorption event.

## Sufficient event state

For subsequent absorption during an already active event, the event-start moisture `theta0` is not independently required if its only future role is through the already evaluated `S_P(theta0)`.

Likewise absolute `t0` is not required if elapsed event age is stored directly.

Therefore a sufficient analytical event-history representation is:

```text
S_event
age_event
```

per active domain/node contact, with an inactive encoding replacing a separate boolean where desired.

The next-step absorption increment follows from:

```text
Delta I =
G * S_event *
[ sqrt(age_event + dt) - sqrt(age_event) ]
```

and after an accepted continuation:

```text
age_event <- age_event + dt
```

A newly initiated contact event sets:

```text
S_event   <- S_P(theta_current_at_first_contact)
age_event <- 0
```

An ended event invalidates/resets the event state according to the chosen explicit-state contract.

## Why one cumulative scalar is not sufficient in general

Suppose geometry is fixed and define:

```text
I = S * sqrt(age)
```

Two states can have the same cumulative absorption but different future increments.

Example:

```text
A: S = 1, age = 4  -> I = 2
B: S = 2, age = 1  -> I = 2
```

For `dt = 1`:

```text
Delta I_A = sqrt(5) - sqrt(4)          ~= 0.236
Delta I_B = 2 * [sqrt(2) - sqrt(1)]   ~= 0.828
```

Thus equal cumulative absorption does not imply equal future response.

A single scalar `I` is therefore not a sufficient Markov state for arbitrary event-start sorptivity.

Similarly, age alone is insufficient because event-start sorptivity varies with event-start matrix moisture.

## Reduced-state conclusion

For exact preservation of the Philip-event absorption operator, the natural lower-bound candidate is two real-valued history degrees of freedom per active sorption contact:

```text
S_event
age_event
```

rather than the legacy semantic representation:

```text
SorpDmCp
ThtSrpRefDmCp
TimAbsCumDmCp
FlEndSrpEvt
```

provided source replay confirms that `ThtSrpRefDmCp` and `FlEndSrpEvt` have no independent future use outside creation/reset of these two sufficient statistics.

This proviso is mandatory. The analytical reduction follows from the published absorption equation; complete legacy-source equivalence still requires exact B1.11 trace.

## Candidate encoding

A future typed research state may use:

```fortran
type :: MacroporeSorptionHistory
   real(8), allocatable :: event_sorptivity(:,:)
   real(8), allocatable :: event_age(:,:)
end type
```

Inactive contact can be represented explicitly by a separate bitset/logical mask or by a safe sentinel contract. No production representation is selected here.

## Transaction semantics

Both quantities are physical/history continuation state.

Trial execution may update event age or create/end an event only in candidate state.

On rejection:

```text
accepted S_event, age_event remain unchanged
```

On acceptance both are committed atomically with matrix and fast-domain storage.

This directly avoids the historical partial-rollback problem where some sorptivity/reference fields were trial-mutable but incompletely restored.

## Research implication

The result changes the reduced-model target from:

```text
S_p + arbitrary legacy sorption arrays
```

to the much sharper hypothesis:

```text
S_p
+ 2-value Philip-event history where sorptivity absorption is active
+ separate wet-wall history only if F-MACRO-ALT03 proves it independently causal
```

This is a physics/state reduction, not yet a production implementation.
