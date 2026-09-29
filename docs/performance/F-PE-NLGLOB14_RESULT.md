# F-PE-NLGLOB14 result — saturation-boundary temporal-event localization

Date: 2026-09-29

Status:

`NLGLOB14_LINEAR_EVENT_ESTIMATE_INSUFFICIENT`

Canonical base:

`integration/f-ci-canonical@7ea6fc05ef589e3adb3e26ef1d436e514604197f`

Qualification authority:

- workflow run: `36559551096`;
- job: `109376827609`;
- conclusion: SUCCESS.

## Frozen question

Can the first prospective accepted TG crossing of `theta_s` be localized by the preregistered linear event fraction

`phi_sat = (theta_s-theta_n)/(theta_TG^*(h)-theta_n)`

and then integrated conservatively to that event state?

## Coverage

PASS.

All five frozen O05/TG near-saturation targets produced a finite event fraction with:

`0 < phi_sat < 1`.

The selected crossing node is node 16 in all five targets.

Observed event fractions:

- HEAD, dt 2.5e-4 d: about 0.65741;
- HEAD, dt 1.25e-4 d: about 0.13443;
- HEAD, dt 6.25e-5 d: about 0.25094;
- RUNOFF, dt 2.5e-4 d: about 0.65741;
- RUNOFF, dt 1.25e-4 d: about 0.13443.

No process failures occurred.

## Event-trial result

All five event trials remain accepted-state retention-inadmissible.

Domain-failing event trials:

`5 / 5`.

Successful admissible event trials:

`0 / 5`.

Therefore the preregistered primary negative gate applies:

`NLGLOB14_LINEAR_EVENT_ESTIMATE_INSUFFICIENT`.

## Interpretation

The saturation event exists inside the nominal interval, but the accepted TG event function is nonlinear in temporal fraction.

Linear interpolation between the accepted origin and the full prospective TG state systematically overestimates the admissible event fraction on this bank.

This is not evidence against saturation-event treatment itself.

It falsifies only the one-shot linear estimate.

The existing bracket is still useful:

- at phi = 0 the accepted origin is strictly inside the retention domain;
- at the linear phi estimate the prospective accepted TG state is above saturation.

Therefore the event time is bracketed.

## Consequence

Do not damp or empirically scale `phi_sat`.

Open a separately preregistered root-localization workunit that solves the temporal event condition from the same physical origin:

`g(phi) = max_i(theta_TG^*(phi h)-theta_s,i) = 0`.

The method should use a bracket-preserving root algorithm, with no accepted-state clipping and no additional subdivision-depth interpretation.

A bounded bisection formulation is admissible because it follows directly from the event contract rather than fitting a damping factor.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
