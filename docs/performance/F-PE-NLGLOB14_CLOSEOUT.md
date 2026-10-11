# F-PE-NLGLOB14 closeout — saturation-boundary temporal-event localization

Date: 2026-09-29

Final status:

`NLGLOB14_LINEAR_EVENT_ESTIMATE_INSUFFICIENT`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@7ea6fc05ef589e3adb3e26ef1d436e514604197f`

Qualification authority:

- run `36559551096`;
- job `109376827609`;
- conclusion: SUCCESS.

## Closure

NLGLOB14 closes the one-shot linear saturation-event estimate negatively.

All five target trajectories provide a valid finite event fraction in (0,1), but all five event trials remain retention-inadmissible.

The selected crossing node is consistently node 16.

No process failure is observed.

## Scientific conclusion

The event is temporally bracketed, but the accepted TG saturation event function is nonlinear enough that direct linear interpolation in accepted moisture does not localize the boundary.

The correct next step is root localization of the event function itself, not empirical damping of the event fraction and not deeper timestep subdivision.

## Direct successor

Open:

`F-PE-NLGLOB14A — bracketed saturation-event root localization`.

Freeze the temporal event function:

`g(phi) = max_i(theta_TG^*(phi h)-theta_s,i)`.

For each target:

- lower bracket phi=0 is the admissible accepted origin;
- upper bracket is the NLGLOB14 linear event estimate, which is retention-inadmissible;
- use bracket-preserving bisection only;
- no clipping;
- no secant/Newton extrapolation outside the bracket;
- no h/16 interpretation;
- no production integration.

The root solve must stop only on a preregistered physical event-distance criterion derived from the existing `5e-8 cm` water-depth authority, or on a preregistered maximum bisection count.

After a positive localization result, a separate event-split workunit may integrate the remainder interval.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14

BASELINE: `7ea6fc05ef589e3adb3e26ef1d436e514604197f`

BRANCH: `research/f-pe-nlglob14-saturation-event`

STATUS: closed negative

IMPLEMENTATION STATUS: linear event probe persisted

TEST STATUS: focused run PASS

QUALIFICATION STATUS: `NLGLOB14_LINEAR_EVENT_ESTIMATE_INSUFFICIENT`

NEXT SAFE STEP: preregister NLGLOB14A bracketed event root localization

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
