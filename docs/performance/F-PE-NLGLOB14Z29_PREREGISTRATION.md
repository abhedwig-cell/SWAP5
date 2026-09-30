# F-PE-NLGLOB14Z29 preregistration — reduced physical moving-interface binding

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@47e7f81ea2fb12f70424ce10eea20871715fad14`

Parent authority:

- Z20-Z22: accepted-state moving-interface semantics and bidirectional one-face motion qualified;
- Z25: chatter causes no retry/substep burden;
- Z26: chatter is not a Newton-iteration spike;
- Z27: the old research harness is fixed-dimension;
- Z28: variable-dimension production workspace/TRIDAG primitives are qualified for n=11,12,13,16.

## Purpose

Bind the qualified moving-interface physics to a genuinely reduced nonlinear solve for the first time.

Z29 is a local physical-equivalence workunit around the already-qualified event windows. It does not yet replace the production solver.

## Reduced-state formulation

The full 16-node accepted state remains sole physical authority.

For an accepted contiguous saturated lower tail beginning at node `s`:

- nodes `1..s-1` are ordinary unsaturated/transition unknowns;
- node `s` — the shallowest currently saturated node — is retained as the active boundary/release guard;
- nodes `s+1..16` form an algebraically reconstructed saturated lower tail.

Thus the reduced nonlinear dimension is:

`n_active = s`

for tails `s:16`.

This keeps the currently shallowest saturated node inside the nonlinear solve so it may desaturate on a retreat, while node `s-1` remains active so it may saturate on a reverse/expansion event.

This deliberately keeps one node above the reconstructed saturated tail active so retreat/release can occur without hysteresis or suppression.

If no valid contiguous lower saturated tail exists, the reduced route is unavailable and no claim is made.

## Saturated-tail reconstruction

The reconstructed lower tail must satisfy exactly:

- theta = theta_s;
- K = Ksat where saturated;
- one contiguous tail ending at node 16;
- one shared lower-tail flux equal to the prescribed bottom flux for the frozen fixtures;
- the same face-flux sign convention as the full reference;
- exact geometric head increments implied by Darcy flux and Ksat.

The first reconstructed saturated node is node `s+1`; it is determined from the active guard-node state at node `s` and the shared tail flux.

No fitted threshold, smoothing, dwell or mass redistribution is permitted.

## Frozen physical fixtures

Reuse exactly the two fine O05 trajectories:

- HEAD, dt = 6.25e-5 d;
- RUNOFF, dt = 6.25e-5 d.

Use the same route, forcing, constitutive providers, qbot=0 and dynamic-top semantics as Z22/Z26.

## Frozen observation windows

Run the unchanged full-reference trajectory as authority.

At every interval in the Z26 event/control windows:

1. capture the exact full-reference origin state;
2. compute the normal full-reference candidate;
3. independently compute one reduced candidate from the same origin;
4. do not advance the trajectory with the reduced candidate;
5. compare candidates.

Required windows are:

- first chatter burst + settlement + post-control;
- second chatter burst + settlement + matched pre/post controls.

The reduced route is therefore observer-only in Z29.

## Frozen equivalence diagnostics

Per compared interval record:

- route;
- step/time;
- reference starting tail;
- reduced n_active;
- full Newton iterations;
- reduced Newton iterations;
- full algebra dimension = 16;
- reduced algebra dimension;
- max absolute pressure-head difference;
- max absolute theta difference;
- ponding difference;
- top-flux difference;
- lower-tail reconstruction residual;
- physical ledger difference;
- resulting saturated-tail identity;
- ownership-change direction;
- provider route.

## Frozen hard gates

Classify one interval equivalent only if:

- both solves converge;
- all states are finite;
- max theta difference <= 5e-10;
- max pressure-head difference <= 5e-7 cm;
- ponding difference <= 5e-10 cm;
- top-flux difference <= 5e-10 cm/day;
- ledger difference <= 5e-8 cm;
- resulting saturated-tail identity is identical;
- ownership direction is identical;
- dynamic-top route is identical.

These are comparison gates, not new physical acceptance tolerances.

## Frozen work diagnostics

For every equivalent interval report:

- full dimension 16;
- reduced dimension n_active;
- dimension ratio n_active/16;
- full Newton iterations;
- reduced Newton iterations;
- structural dense-Jacobian probe count:
  - full: 16 columns per Newton iteration;
  - reduced: n_active columns per Newton iteration;
- normalized probe work:
  `reduced_iterations*n_active / (full_iterations*16)`.

This is deterministic research-harness work, not production wall-clock.

## Frozen classifications

### REDUCED_PHYSICAL_EQUIVALENCE_QUALIFIED

Require all observed Z26 event/control intervals to pass every equivalence gate.

### REDUCED_PHYSICAL_EQUIVALENCE_PARTIAL

At least one reduced interval is valid and close, but one or more frozen comparison gates fail.

### REDUCED_RELEASE_GUARD_INSUFFICIENT

Failures are localized specifically to retreat/reverse events because one active guard node is insufficient.

### REDUCED_TAIL_RECONSTRUCTION_INCONSISTENT

The analytic saturated tail cannot preserve the full-reference flux/head/mass geometry.

### REDUCED_SOLVE_INCONSISTENT

The reduced nonlinear solve fails independently of the above geometry classifications.

Frozen positive aggregate:

`QUALIFIED_Z29_REDUCED_PHYSICAL_BINDING`.

## Positive consequence

A positive Z29 result authorizes a trajectory-driving reduced manager successor and direct adaptive-vs-full runtime benchmark.

A partial/negative result must localize the missing state before any production implementation.

## Stop rules

Do not:

- advance accepted state with the reduced candidate in Z29;
- alter full-reference trajectory;
- tune thresholds after exposure;
- suppress chatter;
- alter dt/forcing;
- introduce a second accepted-state authority;
- modify production defaults.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z29

BASELINE: `f10fc22c6ee64bbab2b9d99c7b101cd875e9fc43`

BRANCH: `research/f-pe-nlglob14z29-reduced-physical-binding`

NEXT SAFE STEP: implement observer-only reduced solve and compare on exact Z26 event/control windows.

## Production boundary

Research physical binding only.

`LEGACY_NUMERICS` remains production default.
