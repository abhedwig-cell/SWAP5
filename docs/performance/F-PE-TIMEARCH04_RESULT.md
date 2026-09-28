# F-PE-TIMEARCH04 result — hard-event density and scheduler ownership

Date: 2026-09-28

Status: `QUALIFIED_EVENT_SCHEDULER_SEPARATION_TARGET`

Canonical authority:

`integration/f-ci-canonical@b0269f6fe7e7cbfcf47095cd6d471eb2fb180036`

Primary evidence:

- Actions run: `36421100806`;
- scheduler job: `108923745175`;
- source guard: PASS;
- 20 preregistered scheduler grid points: PASS.

## Source-bound finding

Current TimeControl still contains both:

1. permanent numerical-bound mutation:
   - `DTMAX = min(DTMAX, 1/NPRINTDAY)`;
   - detailed meteo also reduces DTMAX;
   - DTMIN is then coupled to the mutated DTMAX;
2. exact event clipping through `get_dtevent()`.

Thus output/meteo cadence currently participates both in numerical configuration and in scheduler execution.

## Scenario B — scheduler-only output, exact events retained

When numerical bounds are no longer permanently reduced by output cadence, but exact output hard events are retained:

- median step-count ratio B/A = 1.00;
- only 1/20 grid points changes by >=10%;
- best reduction: about 9.7%;
- worst case: about 41.8% more steps.

Therefore permanent bound mutation is mostly architectural duplication, not a broad steady-state performance lever by itself.

## Why the worst case becomes slower

The slower grid point exposes a second coupling:

- an event clips the executable step;
- the clipped accepted dt then becomes the basis for the next growth proposal;
- the controller therefore loses its pre-event preferred-step memory;
- repeated periodic events can create a fragmentation pattern.

This means simply removing the DTMAX mutation while keeping the rest of legacy controller state semantics is not a correct modern separation.

The target architecture needs separate:

- preferred/proposed dt memory;
- event-limited executed dt.

An event clip should be reason-coded so the proposal controller can decide whether it represents numerical evidence.

## Scenario C — output-decoupled shadow upper bound

This scenario is explicitly counterfactual and does not claim current output semantics permit decoupling.

Results:

- material reduction in 14/20 grid points;
- median step-count ratio C/A = about 0.431;
- fine-output-cadence median ratio = about 0.224;
- minimum observed ratio = about 0.026.

Under this easy-solver scheduler model, removing output as a physical hard stop can therefore reduce step counts very substantially when output cadence is fine and the numerical controller would otherwise prefer much larger intervals.

This is an upper bound only.

## Event classification

### Strong hard-event candidates

These represent forcing/process/external discontinuities and should remain explicit scheduler boundaries:

- detailed meteorological record boundary;
- precipitation event boundary;
- runon event boundary;
- SSDI/irrigation event boundary;
- interception-storage event boundary;
- external generic/coupling interval end.

### Mixed calendar boundary

End-of-day currently owns both:

- daily process semantics;
- legacy numerical-controller restart.

The daily process event may remain hard where required.

The numerical day-start floor should not be owned by the calendar scheduler in a modern controller.

### Reporting/output boundary

Output/print cadence is not intrinsically a physical discontinuity.

It is therefore a valid target for separate output-semantics research.

No production removal is authorized here.

## Decision

TIMEARCH04 qualifies event-scheduler separation as a redesign target.

Two distinct follow-ups are justified:

1. preserve preferred-step controller memory across event clipping;
2. determine whether output can be materialized without forcing physical integration endpoints at every requested output time.

Required immediate successor:

`F-PE-TIMEARCH04A — event-clamp proposal-memory separation`.

## Production boundary

No production `src/**` change.

Final classification:

`QUALIFIED_EVENT_SCHEDULER_SEPARATION_TARGET`.
