# PPA-WU05-PERCH19 result — source-faithful FrReduQ numerical state

Date: 2026-10-01

Status: `CLOSED_QUALIFIED_STATE_MACHINE / TRANSACTION_PROTOCOL_EXTENSION_REQUIRED`

Canonical reconciliation:
`integration/f-ci-canonical@aea20f61381f0c750fc90f2eb5201b8a40efcd73`.

Qualified state-machine postimage:
`1bfef148c129a0e0c40ee8bc1cd8600b30904ed4`.

Qualification run:
`36861781525` — SUCCESS.

## Decision

`QUALIFIED_SOURCE_FAITHFUL_FREDUQ_STATE_MACHINE_REQUIRES_TRANSACTION_RETRY_PROTOCOL`

## Qualified source semantics

PERCH19 implements the exact active source ladder:

- level 0 -> factor 1.0;
- level 1 -> factor 0.1;
- level 2 -> factor 0.01;
- level 3 -> factor 0.001.

It also qualifies:

- no exchange-level mutation before minimum timestep;
- escalation at minimum timestep;
- source retry timestep `sqrt(dtmin*dtmax)`;
- one-level recovery when accepted `dt > dtold`;
- one-level recovery after ten accepted steps when `dt == dtold`;
- fail-closed exhaustion after level 3;
- deterministic initialization;
- persistence roundtrip;
- explicit invalid-persistence rejection.

The exact legacy behavior of continuing after final nonconvergence is documented but not
admitted.

## State ownership

Qualified numerical state consists of:

- reduction level;
- recovery accepted-step counter;
- `dtold`.

This is not physical macropore state.

The seven-field macropore continuation schema remains unchanged.

## A18 relationship

A18 already proves the physical necessity of the source ladder:

- source-backed perched fixture;
- factor 1.0 -> solver retry;
- exact next source level 0.1 -> convergence;
- active perched exchange;
- exact internal and macropore mass closure.

PERCH19 therefore does not invent a new numerical mode. It formalizes a source mechanism
that A18 demonstrated is required.

## Transaction protocol blocker

The current generic transaction executor captures one attempt context and restores it
before retries and before full/half speculative branches.

That is correct for ordinary trial scratch, but source-faithful `IDecMpRat` needs more
specific lifecycle events.

### Why ordinary attempt-context restore is insufficient

If reduction state is simply included in attempt context:

1. a failed solve requests escalation;
2. transaction rollback restores the pre-attempt context;
3. the escalation is erased before the retry.

### Why excluding it from rollback is also wrong

If reduction state is left outside attempt context, a speculative:

- full-step trial;
- half-step trial;
- mass-rejected trial;
- temporally rejected trial

could leak numerical memory into later attempts even though that physical route was never
accepted.

### Required protocol

A source-faithful integration needs two explicit hooks.

#### Post-rollback retry feedback

After restoring physical/trial context for a solver rejection, the transaction layer must
allow the model to apply numerical retry feedback:

- ordinary timestep reduction; or
- exchange-level escalation;
- optional explicit next retry duration.

This is where `IDecMpRat += 1` belongs.

#### Accepted-interval feedback

Only after a physical interval is actually accepted/committed may the model apply
successful-step recovery:

- increment recovery count;
- compare accepted dt with dtold;
- possibly decrement reduction level.

This is where source `NStep/dtold` recovery belongs.

## Existing interface gap

`transaction_model_t` currently exposes:

- advance;
- storage;
- temporal_error;
- attempt-context capture/restore.

It has no model callback for:

- applying retry feedback after rollback;
- applying numerical continuation after final acceptance;
- requesting an explicit retry duration distinct from fixed `retry_scale`.

Therefore wiring PERCH19 directly into the current backend would either lose source
escalation or violate speculative-trial isolation.

## Qualification evidence

Run `36861781525` passed:

- `PPA_WU05_PERCH19_FACTOR_LADDER=PASS`;
- `PPA_WU05_PERCH19_DT_ACTIONS=PASS`;
- `PPA_WU05_PERCH19_RECOVERY=PASS`;
- `PPA_WU05_PERCH19_ROLLBACK=PASS`;
- `PPA_WU05_PERCH19_PERSISTENCE=PASS`;
- `PPA_WU05_PERCH19_STATE_MACHINE_GATE=PASS`;
- O0/O2 identity.

## Next safe step

Open:

`PPA-WU05-PERCH20 — transaction numerical-retry feedback contract`.

PERCH20 should extend the generic transaction protocol with default-no-op hooks so all
existing models remain unchanged, then qualify:

1. retry feedback is applied only after rollback;
2. model can request explicit retry dt;
3. accepted feedback occurs only after final acceptance;
4. temporal/mass rejected speculative branches do not leak numerical state;
5. existing transaction tests remain unchanged when hooks are unused.

Only after PERCH20 is qualified should PERCH19 be connected to the A17 serialized
macropore backend.

No canonical admission is requested from this research ancestry.
