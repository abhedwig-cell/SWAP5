# PPA-WU05-PERCH19 result — source-faithful FrReduQ retry controller

Date: 2026-10-01

Status: `CLOSED_QUALIFIED_CONTROLLER_REQUIRES_NUMERICAL_CONTINUATION_INTEGRATION`

Research baseline:
`research/ppa-wu05-a18-perched-authority-fixture@77f47a7d98cece4b371fdf078525a7ade7daec4a`

Current canonical reconciliation at close:
`integration/f-ci-canonical@e9f210a41bca5bf9c6b9118f91a2be020e76b26f`.

Qualified controller postimage:
`12cf9682fe7a4dfb8c0658dc90ba46e73958a0e3`.

Qualification run:
`36873515942` — SUCCESS.

## Decision

`QUALIFIED_RETRY_LADDER_REQUIRES_NUMERICAL_CONTINUATION_STATE`

PERCH19 qualifies the exact B1.11 `IDecMpRat / FrReduQ` controller equations and
transition ordering.

It does not yet qualify production integration because the controller has accepted-step
memory that must live in an explicit SWAP5 numerical-continuation state.

## Exact source behavior qualified

### Reduction factor

`FrReduQ = 0.1 ** IDecMpRat`

with levels:

- 0 -> 1.0;
- 1 -> 0.1;
- 2 -> 0.01;
- 3 -> 0.001.

### Failure ordering

PERCH19 preserves the source ordering:

1. above `DTMIN`, ordinary temporal reduction owns the retry and the exchange-reduction
   state is unchanged;
2. only at the minimum-step boundary may a failed macropore solve increment
   `IDecMpRat`;
3. after level 3, another failure is terminal for this controller.

The macropore controller deliberately does not invent the ordinary timestep-reduction
factor.

### Exchange-reduction retry timestep

When an exchange-reduction retry is selected at the minimum-step boundary, the exact
legacy next-step rule is represented:

`dt_retry = sqrt(DTMIN * DTMAX)`.

### Recovery after accepted convergence

With `IDecMpRat>0`:

- successful accepted steps increment `NStep` up to 10;
- `NStep>=10` decrements the reduction level by one and resets the counter;
- a successful `dt>dtold` also decrements one level immediately;
- `dtold` is updated at the recovery transition.

## Qualification evidence

Run `36873515942` passed at both O0 and O2 with identical output.

Markers:

- `PPA_WU05_PERCH19_TEMPORAL_ORDERING=PASS`;
- `PPA_WU05_PERCH19_REDUCTION_LADDER=PASS`;
- `PPA_WU05_PERCH19_REJECT_ISOLATION=PASS`;
- `PPA_WU05_PERCH19_RESTART_PAYLOAD=PASS`;
- `PPA_WU05_PERCH19_RECOVERY_RULE=PASS`;
- `PPA_WU05_PERCH19_CONTROLLER_GATE=PASS`;
- `PPA_WU05_PERCH19_O0_O2_IDENTITY=PASS`.

## Ownership result

The minimal controller payload is:

- reduction level;
- successful-step counter;
- previous reduction timestep.

This payload:

- changes numerical retry behavior;
- contributes no physical storage;
- persists across accepted steps;
- must be discarded with a rejected enclosing candidate;
- must survive restart for source-faithful continuation.

It is therefore numerical continuation state, not part of the admitted seven-field
macropore physical state.

## Existing SWAP5 seam

SWAP5 already separates:

`optional_state_layout_id`

from:

`numerical_continuation_layout_id`.

That is the correct architecture.

However, the current serialized macropore admission explicitly requires:

`numerical_continuation_layout_id == FMR_NUMERICAL_CONTINUATION_NONE`.

Therefore the qualified controller cannot be production-integrated as a call-local loop
without dropping source recovery semantics.

## A18 relationship

A18 remains the physical authority:

- solver-stable source-backed Andelst perched baseline;
- active inner callback;
- fixed-factor evidence that factor 1 requests retry and factor 0.1 converges;
- exact internal mass cancellation.

PERCH19 corrects the interpretation of that evidence:

A production controller may not jump directly from factor 1 to 0.1 merely because the
fixed-dt A18 solve requested retry. Ordinary temporal reduction has precedence until its
minimum-step boundary is reached.

## Production status

PERCH19 is not a production-admission candidate.

The next bounded workunit is:

`PPA-WU05-PERCH20 — macropore numerical-continuation state integration`.

PERCH20 should add a dedicated numerical-continuation layout and prove:

- clone/checkpoint/reject/commit;
- restart persistence;
- atomic publication with accepted physical macropore state;
- temporal-retry precedence;
- reduction-level retry at the minimum-step boundary;
- ten-step/larger-dt recovery;
- preservation of the default A8-A10/RFM routes when the layout is absent.

Any eventual canonical admission branch must be reconstructed from then-current canonical
because the historical perched ancestry conflicts with later canonical RFM workunit names.
