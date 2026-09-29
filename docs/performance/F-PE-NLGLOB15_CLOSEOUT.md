# F-PE-NLGLOB15 closeout — physical desaturation/release probe

Date: 2026-09-29

Final status:

`BLOCKED_NLGLOB15_RELEASE_COVERAGE`

Qualification authority:

- run `36564258322`;
- job `109392235771`;
- conclusion: SUCCESS.

## Closure

NLGLOB15 does not establish either presence or absence of a representational release signal.

The zero-supply drying phase exposes a more immediate semantic dependency:

all five drying trajectories undergo a dynamic-top provider route transition, while the inherited same-route research driver terminates on route mismatch.

Therefore the extended release trajectory is not observable with this harness.

## Preserved evidence

Before route termination:

- all five cases enter persistent saturated mode;
- drying-phase accepted states are finite;
- observed interval mass remains within authority;
- no unsafe RLS0 state is observed.

No release threshold, hysteresis or state-machine switch was tested.

## Direct successor

Open:

`F-PE-NLGLOB15A — route-flexible drying/release attribution`.

The successor is diagnostic-only and must keep the dynamic-top provider unchanged.

It must allow physical provider route transitions during the drying phase while preserving:

- the committed physical state;
- persistent saturated KLAG temporal mode;
- S0/R0 endpoint certificates;
- zero-supply forcing;
- mass accounting;
- exact RLS0 definition.

Only after route-flexible coverage is obtained may the release signal be classified.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB15

STATUS: blocked on route-flexible drying coverage

TEST STATUS: focused probe PASS mechanically

QUALIFICATION STATUS: `BLOCKED_NLGLOB15_RELEASE_COVERAGE`

NEXT SAFE STEP: preregister/execute NLGLOB15A route-flexible drying attribution

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
