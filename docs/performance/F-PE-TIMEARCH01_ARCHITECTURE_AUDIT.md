# F-PE-TIMEARCH01 — timestep architecture audit and redesign frame

Date: 2026-09-28

Status: `ARCHITECTURE_AUDIT_ACTIVE`

Canonical authority:

`integration/f-ci-canonical@3b94726fe7d01aec42a5a53587769f38916203f4`

## Trigger

F-PE-BOFEK01/02, PRACTICAL01-03, STATESTEP01-03, EMBEDSTEP01-02 and DYNERR01 collectively show that repeatedly tuning the current timestep parameters does not produce a robust production policy.

At the same time, several experiments show that materially larger timesteps can reduce solver work when they happen to be safe.

The remaining question is therefore architectural:

> Is the legacy SWAP timestep-regulation model itself the limiting abstraction?

This workunit does not start from DTMIN/DTMAX tuning. It starts from responsibility ownership.

## Current architecture inventory

The current SWAP TimeControl mutates one shared `dt` from multiple conceptually different mechanisms.

### 1. Numerical-performance adaptation

After an accepted step:

- if `numbit <= NUMBIT_CRIT`: `dt = min(dt * fact_dt_increase, DTMAX)`;
- if `numbit >= MAXIT`: `dt = max(dt * fact_dt_decrease, DTMIN)`.

This is an iteration-count heuristic, not a temporal-error estimate.

### 2. Solver-failure recovery

When `fldecdt` is raised after nonlinear failure:

- `dt = dt / fact_dt_fldect`;
- floor at `DTMIN`.

This is rejection/retry policy.

### 3. Macropore recovery

When `FlDecMpRat` is raised:

- `dt = sqrt(DTMIN * DTMAX)`.

This is process-specific failure recovery.

### 4. Event alignment

`get_dtevent()` clips dt to avoid crossing:

- end of day;
- output timestamps;
- detailed meteorological records;
- precipitation events;
- subsurface-irrigation events;
- runon events;
- generic transaction interval end.

These are hard time-axis discontinuities, not numerical timestep decisions.

### 5. Process-specific event clipping

Separate calls also clip dt for:

- interception storage event `dt_interc_event`;
- irrigation event `dt_irr_event`.

Again these are event boundaries.

### 6. Day-boundary restart policy

At start of a day:

`dt = max(dt, sqrt(DTMIN*DTMAX))`.

This deliberately discards part of the previous-day adaptive history.

### 7. Input-bound mutation

At initialization:

- `DTMAX` is silently reduced to output-frequency and detailed-meteo limits;
- `DTMIN` is silently reduced to at most `0.1*DTMAX`;
- initial dt is often set to `sqrt(DTMIN*DTMAX)`.

Therefore DTMIN/DTMAX are not merely user numerical bounds. They are entangled with scheduling and initialization.

## Newer SWAP5 control layers

The legacy internal TimeControl is no longer the only adaptive-control layer.

SWAP5 also has:

### Transaction retry

The generic transaction core can:

- reject a trial;
- reduce the requested interval by `retry_scale`;
- retry from the same committed origin;
- commit only one accepted endpoint.

### Temporal acceptance

Depending on the qualified profile, SWAP5 can additionally use:

- full-versus-two-half temporal acceptance;
- model temporal certificates;
- history-aware temporal budgets.

### Coupling windows

MODFLOW/MultiSWAP coupling introduces an externally requested interval that must be covered atomically.

### Generic interval clipping

F-CI11 added the transaction interval end into legacy `get_dtevent()`, so external interval ownership currently enters the legacy event-clipping machinery.

## Architectural problem statement

The current system has at least four separate classes of concern that all affect effective timestep length:

1. hard event scheduling;
2. temporal-accuracy control;
3. nonlinear-solver failure recovery;
4. performance adaptation.

They are currently only partially separated.

This makes it difficult to answer basic questions such as:

- Why was this particular dt chosen?
- Was dt small because of physics, nonlinear convergence, output timing, rainfall discontinuity or a user cap?
- Did two independent controllers both reduce the same interval?
- Is DTMAX limiting accuracy, scheduling or only performance exploration?
- Does a day boundary change numerical behavior for reasons unrelated to physics?
- Can an external coupling interval use a modern controller without legacy day-control heuristics interfering?

## Evidence from recent performance work

### Static global tuning

No strict global DTMIN/DTMAX/adaptation policy qualified.

### Practical static policies

Large dt values can reduce deterministic solver work by roughly 20-50% in suitable regimes, but static soil/regime policies fail near wet transitions.

### Accepted-state adaptive control

A normalized head-change controller showed roughly 34% work reduction on passing cases, but could not reliably predict wet-transition failures.

### Selective temporal refinement

Preserving Reference TimeControl within its current envelope and using two half steps only above that envelope restored most robustness:

- 15/16 P-C1 pass;
- all wet/ponding cases passed;
- but only about 5.7% median work gain remained after refinement cost.

### Dynamic-top defect indicator

The fixed-flux temporal defect indicator does not generalize to dynamic top:

- rank correlation only about 0.45;
- one severe false-safe at a flux-to-head boundary-path transition.

These results indicate that the major remaining issue is control architecture and observability, not another scalar DTMAX calibration.

## Target architecture hypothesis

A replacement architecture should separate five services.

### A. HardEventScheduler

Responsibility:

Return the earliest time that must not be crossed because forcing, process ownership or an external contract changes.

Examples:

- meteo discontinuity;
- rain/runon event;
- irrigation/interception event;
- coupling-window end;
- calendar/output event only when exact state-at-time semantics really require it.

It does not decide numerical accuracy.

Interface concept:

`hard_stop = next_event_after(t)`

### B. StepProposalController

Responsibility:

Propose a preferred numerical dt from accepted-state/history/error information.

It does not know calendar/output logic.

Interface concept:

`dt_preferred = propose(history, state, solver_history, accuracy_profile)`

### C. TrialExecutor

Responsibility:

Execute one requested interval transactionally from an immutable accepted origin.

It returns:

- converged or failed;
- endpoint state;
- integrated fluxes;
- nonlinear diagnostics;
- cheap temporal/error diagnostics when available.

It does not itself choose the next dt.

### D. AcceptanceController

Responsibility:

Decide whether a converged trial is accurate enough to commit.

Potential inputs:

- mass completeness;
- temporal error/certificate;
- boundary-transition diagnostics;
- coupling accuracy requirements.

### E. RetryController

Responsibility:

Choose a smaller retry interval after:

- nonlinear failure;
- temporal rejection;
- process-specific failure.

Retry reason is explicit. It is not encoded only through mutation of global `dt`.

## Proposed timestep selection sequence

For accepted origin at time `t`:

1. `dt_pref = StepProposalController(...)`;
2. `t_event = HardEventScheduler.next_event(t)`;
3. `dt_request = min(dt_pref, t_event-t, external_window_remaining)`;
4. execute transaction trial;
5. if nonlinear failure: RetryController receives reason `SOLVER_FAILURE`;
6. if converged but temporal acceptance fails: RetryController receives reason `TEMPORAL_ERROR`;
7. if accepted: commit and update controller history;
8. repeat.

This is materially different from allowing many routines to mutate shared `dt`.

## DTMIN / DTMAX design question

TIMEARCH01 deliberately does not assume that user-facing DTMIN and DTMAX should survive.

Three candidate future semantics must be distinguished.

### Option A — retain as user policy

User continues to choose both.

This preserves compatibility but keeps expert numerical tuning in normal input.

### Option B — convert to safety bounds

The controller chooses dt automatically.

- DTMIN becomes an emergency numerical floor / abort criterion;
- DTMAX becomes an optional hard safety/debug ceiling;
- neither is the normal performance-control mechanism.

### Option C — remove from ordinary user input

The model owns numerical timestep selection.

Users choose an accuracy/performance profile rather than dt bounds.

Internal safety minima/maxima remain implementation constants or advanced expert overrides.

TIMEARCH01 treats B and C as serious candidates.

## Important event-policy issue

The current code clips `DTMAX` to output frequency.

A modern architecture should challenge this.

Output times do not necessarily need to be numerical-step boundaries if:

- required output quantities can be interpolated consistently;
- cumulative fluxes can be partitioned exactly;
- state snapshots can be materialized at requested output times without changing the physical trajectory.

However this is not assumed safe. Existing exact output/event semantics must be audited before removing such boundaries.

Meteorological/rain/runon forcing discontinuities are stronger candidates for genuine hard stops.

## Day boundary issue

The current start-of-day rule raises dt to at least `sqrt(DTMIN*DTMAX)`.

A physically continuous simulation therefore changes numerical-controller history at midnight.

TIMEARCH01 classifies this as an architectural smell unless a process contract specifically requires it.

A successor should test whether removing only this numerical day reset changes:

- runtime;
- trajectory;
- water balance;
- legacy compatibility.

## Process-specific timestep ownership

Interception, SSDI, macropores and similar processes currently influence dt through specialized flags or event variables.

Target rule:

A process may expose one of only two things:

1. a hard next-event time;
2. a typed retry/rejection reason.

It should not independently mutate the global next-step policy.

## Observability requirement

Before replacing TimeControl, SWAP5 needs a timestep decision trace.

Every attempted interval should be attributable to typed causes:

- `PROPOSAL_CONTROLLER`;
- `HARD_EVENT_CLAMP_<type>`;
- `EXTERNAL_WINDOW_CLAMP`;
- `SOLVER_RETRY`;
- `TEMPORAL_RETRY`;
- `PROCESS_RETRY_<type>`;
- `SAFETY_FLOOR`;
- `SAFETY_CEILING`.

Without this trace, performance experiments cannot distinguish controller inefficiency from unavoidable event density.

## TIMEARCH01 decision

The current architecture is sufficiently entangled that further direct DTMIN/DTMAX tuning is not the preferred main line.

Recommended next workunit:

`F-PE-TIMEARCH02 — timestep decision attribution and shadow-controller architecture`

TIMEARCH02 should be observation-first:

1. instrument/replicate current timestep decisions with typed reason attribution;
2. quantify how many accepted/attempted steps are caused by each mechanism;
3. quantify deterministic solver work associated with each reason;
4. run a shadow modern controller that proposes dt but does not control the simulation;
5. determine where the shadow proposal differs from actual dt and why;
6. only after that design a replacement controller.

## Production boundary

TIMEARCH01 is architecture/audit only.

No production timestep semantics change here.

