# PPA-WU05-PERCH19 source and ownership map — IDecMpRat / FrReduQ

Date: 2026-10-01

Status: `EXACT_SOURCE_MAP / NUMERICAL_CONTINUATION_REQUIRED`

## Exact B1.11 source

Authority remains the user-supplied exact SWAP 4.3.1 source.

### Rate factor

`MACRORATE` sets:

`FrReduQ = 0.1 ** IDecMpRat`.

All relevant matrix/macropore exchange branches multiply their potential flow by
`FrReduQ`, including saturated exchange, unsaturated absorption and rapid drainage.

### Failure ordering in HeadCalc

After nonlinear iteration exhaustion:

1. if `flDtMin` is false:
   - restore soil state variables;
   - set ordinary `flDecDt=true`;
   - return for a smaller timestep;

2. else, if macropores are active and `IDecMpRat<3`:
   - increment `IDecMpRat`;
   - set `FlDecMpRat=true`;
   - set `dtold=dt`;
   - clear `flDtMin`;
   - return;

3. otherwise use terminal non-convergence handling.

Therefore exchange reduction is subordinate to ordinary timestep reduction.

### Retry timestep after exchange reduction

`TimeControl(5)` handles `FlDecMpRat` by setting:

`dt = sqrt(dtmin * dtmax)`.

This is a separate source action from the ordinary timestep-reduction branch.

### Recovery after convergence

When convergence is reached and `IDecMpRat>0`:

- increment `NStep` up to 10;
- if `dt > dtold` or `NStep >= 10`:
  - set `dtold=dt`;
  - reset `NStep=0`;
  - decrement `IDecMpRat`.

Thus the controller is not call-local scratch. It has accepted-step memory.

## SWAP5 ownership classification

The source variables:

- `IDecMpRat`;
- `NStep`;
- `dtold`;

are **numerical continuation state**, not physical macropore state.

They:

- change retry policy and nonlinear forcing;
- do not contribute physical water storage;
- must survive accepted steps for source-faithful recovery;
- must not be committed when an enclosing transaction rejects the trial;
- must survive restart if execution is to continue source-faithfully.

They therefore do not belong in the admitted seven-field macropore physical continuation
payload.

## Existing SWAP5 architecture

SWAP5 already has a separate template axis:

`numerical_continuation_layout_id`.

Existing values include:

- `FMR_NUMERICAL_CONTINUATION_NONE`;
- `FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY`.

The serialized backend also already contains a numerical-continuation state subtype for
accepted temporal derivative history.

However, the current macropore admission explicitly requires:

`optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_MACROPORE`

and:

`numerical_continuation_layout_id == FMR_NUMERICAL_CONTINUATION_NONE`.

Therefore production source-faithful `FrReduQ` recovery cannot be added merely as a
local loop in `mod_macropore_single_column_runtime`.

A new numerical-continuation layout is required.

## Required continuation payload

The minimal exact payload is:

- integer reduction level `0..3`;
- integer accepted-success counter `0..10`;
- previous reduction timestep `dtold >= 0`.

Current factor is derived, not stored:

`factor = 0.1 ** reduction_level`.

## Transaction semantics

For each trial:

1. clone accepted numerical continuation state;
2. ordinary timestep reduction occurs before any exchange-level escalation;
3. at the minimum-step boundary, retry may advance only the trial-local controller;
4. rejected enclosing candidates discard that controller candidate;
5. accepted candidates publish both physical state and numerical continuation atomically;
6. restart restores both.

This keeps rejected physical and numerical attempts from leaking into committed authority.

## A18 relationship

A18 run `36860834649` proved that, at fixed `dt=0.002 d`:

- factor 1.0 requests retry;
- factor 0.1 converges;
- active perched exchange and mass cancellation are correct.

That evidence proves the factor is physically/numerically consequential.

It does **not** override the source ordering above. Production PERCH19 must still allow
ordinary timestep reduction to reach its minimum-step condition before escalating
`IDecMpRat`.

## Architecture decision boundary

A pure controller can qualify the exact ladder, failure ordering and recovery equations.

Production integration additionally requires:

- a new FMR numerical-continuation layout ID;
- a committed/candidate state carrier for the three controller values;
- clone/checkpoint/reject/commit/restart support;
- macropore admission compatibility with that numerical layout;
- orchestration of ordinary temporal retry versus exchange-reduction retry.

Until that continuation surface is implemented, PERCH19 is not a production-admission
candidate.
