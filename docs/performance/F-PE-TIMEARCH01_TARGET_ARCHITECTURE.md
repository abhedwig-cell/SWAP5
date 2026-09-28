# F-PE-TIMEARCH01 target timestep architecture

Date: 2026-09-28

Status: `TARGET_ARCHITECTURE_DRAFT_FOR_EXECUTABLE_PROOF`

Canonical authority:

`integration/f-ci-canonical@3b94726fe7d01aec42a5a53587769f38916203f4`

## Design goal

Replace one mutable legacy `dt` control surface with explicit ownership.

The target design separates:

1. numerical step proposal;
2. hard event scheduling;
3. process constraints;
4. nonlinear trial recovery;
5. temporal-accuracy acceptance;
6. transaction commit/rollback.

A timestep is no longer “the value stored in dt”. It is the result of a typed decision pipeline.

## Core objects

### Accepted-step context

Immutable input to the controller after a committed step:

- accepted start/end time;
- accepted dt;
- nonlinear iteration count;
- backtracks/retries;
- solver status;
- optional temporal indicator;
- optional state/history summaries;
- active-process flags.

No rejected physical state is allowed here.

### Numerical step proposal

The controller returns:

- `preferred_dt`;
- optional `soft_min_dt`;
- optional `soft_max_dt`;
- reason/provenance.

This is a proposal, not yet an executable interval.

### Event horizon

A scheduler independently returns the next hard time boundary:

- external requested interval end;
- meteo discontinuity;
- rainfall/runon discontinuity;
- irrigation/interception event;
- process discontinuity;
- output boundary only if output semantics genuinely require exact state there;
- calendar boundary only if a process requires it.

The executable dt is clipped to:

`hard_event_time - current_time`.

The scheduler does not modify controller configuration.

### Process timestep constraints

Active physics can publish temporary constraints such as:

- maximum interval;
- must-hit event;
- retry-only restriction.

These constraints carry a process-owned reason code.

They are not written into global `DTMAX`.

### Trial recovery policy

A failed trial returns:

- retryable/fatal;
- failure reason;
- suggested reduction or retry scale;
- work budget consumed.

Retry duration is derived from the failed trial.

It does not alter accepted-step controller history until a step is actually committed.

### Temporal acceptance

After nonlinear convergence and mass closure, temporal policy may:

- accept;
- reject/retry;
- request refined evaluation.

Temporal rejection is distinct from solver rejection.

### Transaction layer

Only accepted physical state can replace committed state.

This remains the final authority and is already canonical SWAP5 architecture.

## Decision pipeline

At committed time `t`:

1. controller proposes preferred numerical dt;
2. process constraints narrow the admissible interval;
3. event scheduler clips to next hard boundary;
4. execute one transactional trial;
5. if nonlinear failure:
   - rollback;
   - trial-recovery policy chooses retry dt;
   - return to step 4 without modifying accepted controller history;
6. if solve converges:
   - check mass accounting;
7. optional temporal acceptance:
   - accept or rollback/retry/refine;
8. commit accepted state;
9. create new accepted-step context;
10. controller proposes next preferred dt.

## What happens to DTMIN and DTMAX

### DTMAX

In the target architecture `DTMAX` is not the primary timestep selector.

Three separate concepts replace it:

- controller preferred dt, dynamic;
- optional global safety ceiling, normally internal;
- hard event/process caps, dynamic and reason-coded.

For legacy input compatibility, a user-supplied DTMAX can initially map to an optional safety ceiling.

The long-term default should not require the user to know a correct DTMAX.

### DTMIN

A global user DTMIN is also not a scientific temporal-accuracy setting.

It currently serves multiple roles:

- retry floor;
- endless-reduction guard;
- conditioning/balance interaction;
- historical input compatibility.

Target architecture replaces this with:

- minimum retryable duration / numerical floor owned by solver profile;
- explicit retry/work budget;
- fatal or escalated status if the floor is reached.

A user DTMIN can remain as legacy compatibility override, not as required normal input.

## Legacy compatibility profile

A `LEGACY_REFERENCE` controller can reproduce current behavior intentionally:

- initial dt = sqrt(dtmin*dtmax);
- accepted step:
  - if iterations <= NUMBIT_CRIT: multiply by increase factor;
  - if iterations >= MAXIT: multiply by decrease factor;
- failed trial:
  - divide by failure factor;
- apply legacy day-start floor if compatibility requires exact historical behavior;
- event scheduler supplies all historical hard boundaries.

This profile allows migration without deleting reproducibility.

## Modern profile

A future `ADAPTIVE_REFERENCE` profile should not inherit legacy formulas automatically.

Its controller may use:

- accepted-state/history signals;
- temporal defect or predictor;
- solver difficulty history;
- process-specific error metrics;
- coupling objective.

But it must consume the same contracts.

## Output is not automatically a numerical event

The current code reduces `dtmax` to output cadence.

The target architecture distinguishes:

- state output that must be exact at a requested time: hard event;
- diagnostic aggregation that can interpolate/accumulate from accepted steps: not a timestep constraint.

This should be audited separately before migration because removing unnecessary output-induced clipping may yield speedup without changing solver policy.

## Day boundaries are not automatically numerical events

Calendar-day boundaries remain hard events only for processes whose semantics are daily/discontinuous.

The numerical controller itself does not restart or enlarge dt merely because midnight is crossed.

Legacy day-start `sqrt(dtmin*dtmax)` behavior belongs only to compatibility mode.

## Retry ownership

Long-term target:

- one transaction-level recoverable retry authority;
- legacy `fldecdt` remains only inside the compatibility backend during migration.

A rejected nonlinear trial must not first mutate legacy dt and then be independently retried again by an outer policy without explicit ownership.

## Required observability

Every attempted interval should record:

- proposed dt;
- event-limited dt;
- process-limited dt;
- attempted dt;
- accepted dt;
- proposal reason;
- limiting reason;
- solver rejection reason;
- temporal rejection reason;
- retry index;
- work counts.

This turns timestep behavior from implicit control flow into inspectable data.

## Expected architectural benefits

1. Numerical tuning no longer changes output/event semantics.
2. Event frequency no longer silently mutates a numerical parameter.
3. Rejected trials do not contaminate future accepted-step adaptation.
4. Coupled models can request exact windows without owning SWAP's numerical controller.
5. Different controllers can be compared under identical event/retry contracts.
6. User-facing configuration can become simpler.
7. Performance experiments become attributable to one policy layer.

## Non-goals

The redesign does not:

- alter Richards physics;
- alter BOFEK00 dynamic-top correctness;
- remove event alignment;
- remove mass gates;
- force one specific new adaptive algorithm;
- immediately remove legacy input fields.

## Proposed migration sequence

### TIMEARCH02 — executable decision contracts

Implement test-only pure contracts for:

- proposal;
- event clip;
- process constraint;
- retry decision;
- provenance.

Prove the legacy compatibility profile reproduces the current decision table.

### TIMEARCH03 — event-scheduler extraction characterization

Inventory which current event clamps are physically/semantically hard and which are output/control artifacts.

Measure how often each clamp limits dt in representative workloads.

### TIMEARCH04 — retry ownership reconciliation

Characterize overlap between:

- legacy `fldecdt`;
- transaction retry;
- temporal retry.

Define one production ownership hierarchy.

### TIMEARCH05 — user-interface simplification

Determine whether normal SWAP5 input can omit DTMIN/DTMAX, with:

- automatic defaults/internal solver floor;
- optional advanced safety overrides;
- exact backward-compatible legacy profile.

### TIMEARCH06+ — controller qualification

Only after contracts are admitted should a modern adaptive controller be selected and benchmarked.

## Architecture decision

The target design is technically compatible with canonical transaction, mass, event and coupling invariants.

It also permits exact legacy behavior as a profile.

Therefore the architecture redesign is feasible without a physics rewrite.
