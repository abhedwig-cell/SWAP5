# PPA-WU05-PERCH19 preregistration — source-faithful FrReduQ retry ladder

Date: 2026-10-01

Status: `PREREGISTERED / NUMERICAL_CONTINUATION_MIGRATION`

Baseline:
`integration/f-ci-canonical@ae4eede414692fb0071ea093050f5accd36dd48d`

Source authority:
exact SWAP 4.3.1 nested source archive
`1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.

Owning perched research authority:

- A18 source-backed Andelst perched fixture;
- A18 active inner replay qualification run `36860834649`;
- A17 serialized inner-callback transaction qualification run `36849023154`.

## Purpose

Migrate the exact B1.11 macropore exchange-reduction state machine:

`FrReduQ = 0.1 ** IDecMpRat`

with `IDecMpRat = 0..3`, as an explicit numerical continuation policy.

The reduction state must remain separate from the seven-field physical macropore
continuation state.

## Exact source semantics

On nonlinear failure:

1. ordinary timestep reduction is attempted first;
2. only when the timestep is already at the minimum and
   `IDecMpRat < 3`, increment `IDecMpRat`;
3. set the macropore-reduction retry flag;
4. store the current timestep in `dtold`;
5. clear the minimum-timestep latch;
6. restart with timestep
   `sqrt(dtmin*dtmax)`.

On accepted convergence:

- clear the reduction-retry flag;
- if `IDecMpRat > 0`, increment the successful-step counter up to 10;
- reduce `IDecMpRat` by one when either:
  - the accepted timestep is larger than `dtold`; or
  - 10 successful steps have accumulated;
- when reducing the level:
  - set `dtold = dt`;
  - reset the successful-step counter to zero.

Exchange factors:

- level 0 -> `1.0`;
- level 1 -> `0.1`;
- level 2 -> `0.01`;
- level 3 -> `0.001`.

## Typed continuation state

PERCH19 may introduce numerical continuation fields equivalent to:

- reduction level;
- successful accepted-step counter;
- previous/recovery timestep.

They must not be stored in or counted as part of the seven-field physical macropore
continuation state.

The initial successful-step counter is deterministically zero. Exact B1.11 declares the
saved local `NStep` without an explicit initializer; the observed supported runtime
relies on static-process initialization. SWAP5 must not reproduce undefined initialization.

## Gates

### G1 — source-state transition oracle

Prove exact factor mapping, escalation and de-escalation transitions, including:

- level 0 failure at min dt -> level 1;
- level 1 -> 2 -> 3 bounded escalation;
- no level > 3;
- 10 accepted steps -> one-level recovery;
- accepted larger dt -> immediate one-level recovery;
- no recovery while level = 0.

### G2 — transaction isolation

Rejected attempts may derive candidate numerical continuation but must not mutate the
committed continuation.

### G3 — persistence/restart

Accepted reduction state survives persistence and restart independently of the seven-field
physical macropore state.

### G4 — A18 active perched replay

On the source-backed Andelst perched fixture:

- level 0 must reproduce retry/non-convergence;
- source transition to level 1 must select factor 0.1;
- the level-1 inner solve must converge;
- accepted candidate must carry level 1 numerical continuation;
- internal and macropore mass closure remain exact.

### G5 — recovery semantics

After accepted level-1 operation, qualification must demonstrate at least one exact
source recovery trigger:

- 10 accepted steps; or
- accepted timestep increase.

### G6 — preservation

With PERCH19 disabled or level 0:

- canonical A8/A9/A10 route remains unchanged;
- A16/A17 inner route remains opt-in;
- no new physical-state field is added.

## Non-scope

- no covering-layer extension;
- no dynamic crack feedback;
- no RossFast;
- no parallel MultiSWAP;
- no canonical admission in PERCH19 itself.

## Decision states

- `QUALIFIED_SOURCE_FAITHFUL_FREDUQ_CONTINUATION`;
- `PARTIAL_FREDUQ_CONTINUATION_RESTART_BLOCKED`;
- or `FALSIFIED_FREDUQ_STATE_MACHINE`.

A separate admission reconciliation follows only after PERCH19 is qualified.
