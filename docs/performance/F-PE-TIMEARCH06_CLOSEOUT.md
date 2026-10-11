# F-PE-TIMEARCH06 closeout — production decision-service extraction

Date: 2026-09-28

Final status:

`QUALIFIED_PRODUCTION_DECISION_SERVICE_EXTRACTION`

PR:

`#716 — F-PE-TIMEARCH06: extract production timestep decision services`

## What has changed architecturally

Accepted-step proposal and solver-failure retry arithmetic are no longer only implicit blocks inside monolithic `TimeControl`.

They now have an explicit pure production service with typed decision provenance.

This creates a production seam for future timestep redesign while preserving exact legacy behavior.

## What has not changed

No change to:

- accepted timestep sequence;
- solver retry sequence;
- event clipping;
- day-boundary reset behavior;
- user DTMIN/DTMAX semantics;
- physical equations;
- convergence tolerances;
- mass accounting;
- temporal acceptance;
- coupling-window semantics.

## Why this matters

TIMEARCH01-05 established that the timestep problem is architectural:

- global DTMAX is materially active;
- hard events and numerical proposal are mixed;
- retry ownership is nested;
- output/day control contaminates numerical policy;
- safer modern controllers need explicit ownership and observability.

TIMEARCH06 now moves the first two numerical decisions behind an explicit production boundary without changing results.

That reduces the risk of later replacing the timestep algorithm because the replacement can occur behind a qualified service rather than by editing monolithic TimeControl logic in place.

## Recommended successor

`F-PE-TIMEARCH07 — production decision trace and preferred-dt/event-clamp separation`

TIMEARCH07 should:

1. expose the TIMEARCH06 reason code in runtime diagnostics;
2. record preferred dt before event clipping;
3. record executed/event-limited dt separately;
4. preserve preferred-step memory observationally without changing execution;
5. prove zero trajectory change;
6. provide the production observability needed before any new adaptive algorithm is enabled.

After TIMEARCH07, two separate research decisions become possible:

- whether normal users still need to supply DTMIN/DTMAX;
- which modern proposal controller should replace the legacy iteration-count rule.

## Production boundary

TIMEARCH06 is a structural production extraction only.

No new timestep algorithm is admitted.

