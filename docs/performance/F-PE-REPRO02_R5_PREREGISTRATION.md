# F-PE-REPRO02 R5 — inert boundary-carrier isolation

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

R4 showed that serialized legacy-context binding itself is not causal.

The direct P0 request and serialized participant still differ in two fields that should be semantically inactive for the chosen boundary modes:

- mode 5 prescribed-head lower boundary:
  - P0: `bottom_flux = 0`;
  - participant: `bottom_flux = predictor_qbot = -K(h0)`.
- explicit-flux upper boundary:
  - P0: `top_head = 0`;
  - participant: `top_head = h0`.

## Question

Does either nominally inactive carrier alter the physical nonlinear solve?

## Arms

Start from the successful P0 direct request and apply the legacy-context binder in every arm.

- BASE:
  - bottom_flux = 0;
  - top_head = 0.
- QBOT:
  - bottom_flux = -K(h0);
  - top_head = 0.
- TOPHEAD:
  - bottom_flux = 0;
  - top_head = h0.
- BOTH:
  - bottom_flux = -K(h0);
  - top_head = h0.

All arms retain:

- bottom mode 5;
- explicit-flux top mode;
- identical bottom_head;
- identical top_flux = -K(h0);
- 48/16 effort caps;
- min_step_duration = 1e-10 day.

## Cases

Six difficult PROFILE06 origins.

Offsets:

- -0.001 cm;
- 0;
- +0.001 cm.

Three repetitions per point.

## Decision

If QBOT or BOTH reproduces the serialized participant retry-advised signature, mode-5 physical solve behavior is incorrectly dependent on the nominally inactive bottom-flux carrier.

If TOPHEAD alone changes behavior, the explicit-flux top route is incorrectly dependent on top_head.

If all arms remain identical, continue to serialized state/provider ownership comparison.
