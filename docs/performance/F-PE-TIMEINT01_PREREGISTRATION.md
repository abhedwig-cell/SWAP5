# F-PE-TIMEINT01 preregistration — Richards temporal-discretization reconstruction and modern integrator options

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_INTEGRATOR_SELECTION`

Canonical authority:

`integration/f-ci-canonical@bc365f8d24fb1854ee1484a4f6f9dcc5bc3944fb`

## Trigger

TIMEARCH01-17 established that timestep-control architecture can be separated cleanly from events/retries, but the first AUTO_REFERENCE heuristic controller failed blind validation.

The failure pattern points to missing local temporal-error information rather than another missing DTMIN/DTMAX heuristic.

## Purpose

Reconstruct the exact current time discretization used by the canonical Richards solver and determine which modern adaptive temporal-integration family is technically compatible with:

- discrete water-mass conservation;
- current Newton/Jacobian structure;
- dynamic-top boundary semantics;
- transaction rollback;
- existing constitutive providers;
- practical performance requirements.

No production source modification in TIMEINT01.

## Questions

1. What is the exact formal time discretization of the current mixed Richards residual?
2. What is its formal temporal order away from boundary-regime transitions?
3. Which state/history quantities are required by candidate higher-order methods?
4. Which candidate methods provide a local truncation-error estimate without requiring two additional full nonlinear solves per accepted step?
5. Which methods can preserve mass conservation and the existing dynamic-top physical equations?
6. Which method offers the lowest-risk migration path from current backward Euler?

## Candidate families considered

### A. Embedded/adaptive backward-Euler-derived estimator

A method closely related to the adaptive Thomas-Gladwell / Kavetski-Binning-Sloan family:

- preserve the mass-conservative mixed residual;
- use backward-Euler solution information and derivative/history information;
- estimate local temporal truncation error without unconditional full step-doubling;
- allow smooth timestep changes from a user/model error tolerance.

### B. Variable-step BDF2 with backward-Euler fallback

- first step and discontinuity restart: backward Euler;
- smooth continuation: variable-step BDF2;
- embedded or defect-based estimate from BE/BDF2 relation;
- fallback to BE around regime changes or insufficient history.

### C. Embedded SDIRK / Rosenbrock-type implicit pair

Potentially strong mathematical error control, but likely higher implementation cost because:
- multiple stages;
- dynamic-top boundary must be evaluated consistently per stage;
- mass accounting and transaction state become stage-aware.

### D. Full step-doubling

Already characterized indirectly in EMBEDSTEP.

It remains useful as validation authority but is presumed too expensive as the normal controller because it requires two additional nonlinear solves.

## Advancement logic

TIMEINT01 does not select a production integrator from theory alone.

It may advance one or more prototype candidates to TIMEINT02 only when:

- discrete mass-conservation semantics are explicit;
- required committed history is identified;
- dynamic-top regime-switch semantics are explicit;
- implementation can reuse the current residual/Jacobian substantially;
- expected accepted-step cost is no worse than one extra linear solve or one cheap correction in normal smooth operation;
- full step-doubling is not required on every normal step.

## Literature authority

Primary reference points:

- Kavetski, Binning & Sloan (2001), Adaptive time stepping and error control in a mass conservative numerical solution of the mixed form of Richards equation, Advances in Water Resources 24(6), 595-605, DOI 10.1016/S0309-1708(00)00076-2.
- Kavetski & Sloan (2002), Noniterative time stepping schemes with adaptive truncation error control for Richards equation, Water Resources Research 38, DOI 10.1029/2001WR000720.
- Baron, Coudière & Sochala (2017), Adaptive multistep time discretization and linearization based on a posteriori error estimates for Richards equation, Applied Numerical Mathematics 112, 104-125.
- Bootsma, van der Ploeg & Weerts (2026), Why modified Picard works: Mass-conservative and higher-order time integration for the Richardson-Richards equation, Advances in Water Resources 213, 105327.

## Production boundary

No integrator change, parser change, or AUTO_REFERENCE activation in TIMEINT01.
