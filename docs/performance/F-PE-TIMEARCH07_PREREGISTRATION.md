# F-PE-TIMEARCH07 preregistration — production timestep decision trace

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@70be0aeca1485dd626749d34e5c46aba166e2eb5`

Parents:

- TIMEARCH01 — architecture redesign qualified;
- TIMEARCH02 — executable decision contracts qualified;
- TIMEARCH03 — decision attribution qualified;
- TIMEARCH04 — scheduler separation target qualified;
- TIMEARCH05 — retry ownership hierarchy qualified;
- TIMEARCH06 — production accepted-step/retry decision service extracted with exact legacy preservation.

## Purpose

Expose production timestep decision provenance without changing timestep semantics.

TIMEARCH07 must make the following separately observable for worker-backed execution:

- input/current dt before accepted-step proposal;
- preferred dt returned by the TIMEARCH06 service;
- executed/event-limited dt after legacy hard-event clipping;
- TIMEARCH06 reason code;
- whether event clipping reduced preferred dt.

For solver retry, record:

- input failed-trial dt;
- preferred retry dt;
- retry reason;
- floor reached.

## Carrier ownership

The trace is worker/job-local numerical metadata.

It is:

- not physical state;
- not mass state;
- not a committed column variable;
- not global mutable diagnostic state;
- safe for parallel workers.

Standalone legacy execution without a worker remains supported and unchanged.

## Exact semantic boundary

No change is allowed to:

- accepted dt;
- retry dt;
- event timing;
- get_dtevent logic;
- day-start reset;
- DTMIN/DTMAX mutation;
- process clamps;
- solver convergence;
- physical equations;
- output semantics;
- transaction semantics.

The trace observes current behavior only.

## Required trace fields

At minimum:

- `input_dt`;
- `preferred_dt`;
- `executed_dt`;
- `reason`;
- `event_clipped`;
- `floor_reached`;
- monotonically increasing decision sequence counter.

A trace record is valid only when explicitly marked available.

## Reset semantics

- Worker initialization/release resets trace.
- Accepted-step decisions replace the previous trace with the new accepted-step decision.
- Solver retry decisions replace the previous trace with retry provenance.
- Resetting attempt diagnostics must not accidentally erase a decision already needed for post-attempt attribution unless explicitly requested.

## Qualification gates

A. Direct trace contract:
- accepted-step grow/keep/shrink examples expose exact preferred/executed values and reason;
- event clamp records preferred > executed with event_clipped=true;
- no-clamp records preferred == executed;
- retry records exact TIMEARCH06 retry values/reasons.

B. Worker locality:
- multiple workers can hold independent traces without cross-talk.

C. Semantic preservation:
- existing TIMEARCH06 tests remain exact;
- current Reference BOFEK/trace authority preserves timestep sequence and physical outputs;
- BOFEK00 wet correctness remains green.

D. Source scope:
- only trace plumbing may change around current decision-service calls;
- scheduler formulas remain byte/logic equivalent;
- no new controller formula.

## Decision

If all gates pass:

`QUALIFIED_PRODUCTION_TIMESTEP_DECISION_TRACE`

Production admission is allowed in the same workunit only after current-canonical reconciliation and green preservation CI.
