# F-ROM0TA3 architecture authority

## Decision

F-ROM0TA3 authorizes a narrowly scoped qualification-only fixed-resolution transaction semantic for constructing the ROM-0 numerical Reference floor.

This is not a third production timestep policy.

## Resolved design questions

1. **Qualification context ownership** lives at a dedicated FMR serialized-Reference entrypoint. Ordinary `run_trial` rejects the new mode. The generic canonical configuration alone is therefore insufficient to activate it.
2. **Transaction ownership** remains F-KT. The new mode is implemented inside the existing transaction executor and uses its checkpoint, attempt-context, mass-accounting and commit semantics.
3. **Authority class** is result provenance, not physical state. The committed Richards state remains physically identical in schema. Transaction route/source diagnostics identify the sample as Reference-floor qualification evidence.
4. **Fixed-resolution failure** is terminal for that sample. There is exactly one requested solve attempt. Solver or mass failure does not silently shrink dt.
5. **Restart/replay authority** remains external evidence bound to serialized committed state plus the dedicated entrypoint. No qualification flag is persisted as physical or numerical continuation state.
6. **Resolution observability** uses the existing requested interval, accepted dt, attempts/retries, committed-substep diagnostics and exact external commit count. Qualification requires requested dt == accepted dt, attempts == 1, retries == 0.

## Semantic distinction

Normal temporal acceptance answers:

> Is this candidate accurate enough for the configured application/runtime temporal policy?

Reference-floor qualification answers:

> Is this exact preregistered fixed-resolution Reference sample solver-valid, mass-complete and transactionally committed so it may participate in a cross-resolution numerical-floor study?

The second statement deliberately contains no claim that the timestep is application-accurate.

## Activation boundary

The new transaction enum is necessary inside F-KT so existing state ownership and commit rules remain authoritative. But normal FMR execution must fail closed if a caller puts that enum in ordinary configuration.

Only the dedicated serialized-Reference qualification entrypoint may set the transient in-memory qualification context required for admission. RossFast and optional process layouts are outside this first capability.

## Commit semantics

For one fixed-resolution sample:

- clone the committed checkpoint;
- capture trial context;
- run exactly one Reference solve over the requested interval;
- require solver convergence;
- require complete finite mass accounting within the unchanged mass tolerance;
- capture accepted attempt context;
- move the candidate to the transaction-local committed state;
- publish route/source as Reference-floor fixed resolution;
- expose one commit, one attempt, zero temporal retries and accepted dt equal to requested dt.

No temporal certificate is requested or synthesized.

## Scope

The first qualification is restricted to pure B1.10 one-column hydraulics and exists solely to unblock ROM-0 floor measurement. Any later use outside qualification requires a separate admission decision.
