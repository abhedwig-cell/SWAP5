# F-PE-NLGLOB14G preregistration — forcing-reversal desaturation fixture

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@e46985908b19f83cf2f17f86507aa3495df971a2`

Parent authority:

- NLGLOB14E: `QUALIFIED_COMPLETE_DYNAMIC_TOP_RESEARCH_POLICY`;
- NLGLOB14F: `NLGLOB14F_NO_RELEASE_IN_FROZEN_HORIZON`.

## Purpose

NLGLOB14F established that the qualified wet/near-saturation bank contains no natural desaturation event.

NLGLOB14G therefore creates a separate, physically explicit forcing-reversal fixture to observe release from persistent saturated temporal mode before any release rule is selected.

This workunit remains observational.

It does not switch back to TG.

## Frozen population

Use the eight O05/TG trajectories in the qualified full bank that enter persistent saturated mode:

- routes: HEAD and RUNOFF;
- dt = 0.00025, 0.000125, 0.0000625, 0.00003125 d.

Each trajectory begins from the same initial state and wet forcing as the qualified NLGLOB14E bank.

## Frozen forcing reversal

Before saturated-mode entry:

- preserve the original precipitation forcing exactly;
- potential bare-soil evaporation = 0;
- potential pond evaporation = 0.

After the first completed saturation event + KLAG remainder has entered persistent saturated mode:

- precipitation rate = 0;
- irrigation, snowmelt and runon remain 0;
- potential bare-soil evaporation = the original wet precipitation rate of that trajectory;
- potential pond evaporation = the original wet precipitation rate of that trajectory.

Thus the dry forcing magnitude is exactly the preceding wet precipitation magnitude. No fitted multiplier is allowed.

The forcing is applied only through the existing dynamic-top provider.

## Frozen horizon

Run each fixture to:

`0.012 d`

using its original fixed dt.

The qualified saturation entry occurs within the original 0.001 d bank horizon, leaving at least 0.011 d of explicit drying opportunity.

No adaptive timestep or extra subdivision depth is introduced beyond the already qualified temporal policy.

## Temporal policy during attribution

Use the complete qualified NLGLOB14E research policy:

- unsaturated TG;
- bracketed saturation-event localization;
- KLAG event remainder;
- persistent saturated KLAG;
- unchanged S0/R0 endpoint certificates.

After saturated entry, persistent saturated mode remains active for the full fixture even if the accepted physical state becomes unsaturated.

This is required so NLGLOB14G observes release evidence without already implementing a release rule.

## Frozen release diagnostics

For every accepted persistent-mode interval record all node states and the original saturation-event node.

Define exact constitutive indicators:

`SAT_H(i) = (h_i >= 0)`

`SAT_THETA(i) = (theta_i == theta_s,i)`.

A candidate natural release observation occurs at the first accepted dry-phase interval where the original event node satisfies both:

- `h_event < 0`;
- `theta_event < theta_s`.

At that point also record:

- whether any other active node still satisfies `SAT_H` or `SAT_THETA`;
- route;
- ponding depth;
- top and bottom flux;
- time/step since saturated-mode entry.

No epsilon, head threshold, theta-deficit threshold or hysteresis is introduced.

## Frozen consistency gates

A trajectory is a `CONSISTENT_RELEASE` only if:

1. event-node head and moisture indicators agree before and after release;
2. all accepted states are finite;
3. the paired release signature occurs in an accepted persistent-KLAG interval;
4. no other node remains on the saturated constitutive manifold at the release interval;
5. physical interval and cumulative mass remain <= `5e-8 cm`;
6. the dry forcing diagnostic confirms precipitation=0 and both potential evaporation terms equal the frozen original wet precipitation rate.

## Frozen classifications

If all 8 fixtures produce CONSISTENT_RELEASE:

`NLGLOB14G_FORCING_REVERSAL_RELEASE_SIGNAL`.

If 1 to 7 produce consistent release while all state/mass/forcing guards pass:

`NLGLOB14G_MIXED_FORCING_REVERSAL_RELEASE`.

If 0/8 release while all fixtures remain valid:

`NLGLOB14G_NO_RELEASE_UNDER_FROZEN_REVERSAL`.

If head and moisture indicators disagree at accepted states:

`NLGLOB14G_RELEASE_STATE_INCONSISTENT`.

If physical mass, route/state validity or forcing instrumentation fails:

`BLOCKED_NLGLOB14G_FORCING_REVERSAL`.

## Consequence

A full 8/8 consistent release signal authorizes a separately preregistered release-event localization and mode-switch workunit.

A mixed result requires attribution before any switch rule.

NLGLOB14G itself does not leave saturated mode.

## Stop rules

Do not tune:

- evaporation magnitude;
- horizon;
- release threshold;
- hysteresis;
- timestep;
- event subdivision depth.

Do not switch back to TG in this workunit.

## Architecture invariants

Affected invariants: 7, 9, 13, 23, 25, 26, 30.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14G

BASELINE: `e46985908b19f83cf2f17f86507aa3495df971a2`

BRANCH: `research/f-pe-nlglob14g-forcing-reversal`

IMPLEMENTATION STATUS: preregistration only

TEST STATUS: not started

QUALIFICATION STATUS: not started

NEXT SAFE STEP: materialize frozen forcing reversal and execute the eight target fixtures

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
