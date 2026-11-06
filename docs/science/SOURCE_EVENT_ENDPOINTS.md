# Source-event step endpoints

## Proposed interface and owning scope

The source-window owner `mod_interception_source_window_runtime` defines time
identity with64 machine epsilons at the actual clock scale. The native water
caller currently snaps only daily remainders, while capping against detailed rain
events can leave an unresolvable final source window. Actual Andelst input at
80.423000000001394 to80.423000000002503 carries4.127505354993751e-13cm rain.
Both endpoint values identify the source origin under the existing convention;
source apportionment is zero and the unchanged2.273736754432321e-13cm mass guard
correctly refuses admission before any Richards attempt. The accepted Rutter clock
matches the caller. The original-init corrected run completes80 days; strict own
80 replay reproduces all213 rows and the diagnostic committed stream exactly.

Add pure `select_interception_event_endpoint(cursor,event_end,max_step,endpoint,status)`
to that existing owner. It validates finite ordered clocks and a positive step
ceiling, proposes the bounded endpoint, then selects the exact existing event if
its remainder lies inside the owner's unchanged time-identity convention. An
already committed cursor indistinguishable from the event refuses; it is never
relabelled. Failure returns `INTWIN_INVALID` and zero output. Success returns
`INTWIN_OK` and a strictly advancing endpoint no later than the event. No state,
forcing amount, parameter or restart field is introduced.

The caller selects the next day/rain event and invokes this function BEFORE
initializing the source window or solving. The full constant-rate rain amount is
computed over the chosen interval. This extends the existing daily roundoff
alignment to detailed source events. It does not skip rain, move an accepted
physical state, change DTMIN/DTMAX, weaken mass/temporal/nonlinear checks or alter
source-window processor semantics. The maximum ceiling excess is bounded by the
same pre-existing source-time roundoff convention.

Qualification selects the real source-window and Rutter interfaces at O0/O2:
the actual old lost-remainder witness, exact selected event, whole/split forcing
amounts, unchanged separated events and finite/ordering/nonprogress refusal.
Retain the unmodified INT13 owning composition. A native read-only replay must
start BEFORE the preceding capped step, because a failed-checkpoint cursor has
already passed that choice. Original-initialization481 and exact own year restart
remain separate gates, with no stream rebinding.

Authority: `integration/dataqual15/TRANSITION65_RECOVERY_20261106.json`.
