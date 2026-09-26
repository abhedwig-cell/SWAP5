# F-PE-SHORTSTEP01 P1 — Newton/backtracking path localization

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

P0 confirms that certificate-free Reference-floor convergence is banded and non-monotone in dt. Neighboring durations from identical physical origins can switch PASS→FAIL→PASS.

## Purpose

Locate the first material divergence in the Newton/backtracking trajectory between adjacent successful and failing durations.

## Target contrasts

Primary:

- O05 wet, history -0.1, offset +0.001 cm: 1.875e-5 PASS versus 1.25e-5 FAIL;
- O14 wet, history +0.1, offset -0.001 cm: 5e-5 PASS, 3.75e-5 FAIL, 2.5e-5 PASS;
- B01 wet, history +0.1, offset +0.001 cm: 7.5e-5 PASS, 5e-5 FAIL, 2.5e-5 PASS.

Each point is run in a fresh process from the identical dynamic physical origin.

## Test-only trace

Instrument a copied `headcalc.f90` only. Do not modify production `src/**`.

For each nonlinear iteration record:

- iteration number;
- dt;
- residual objective before Newton step (`sumold`);
- max absolute residual before Newton step;
- max absolute Newton update;
- each backtracking try and factor;
- residual objective and max residual after the trial update;
- whether that backtracking try is accepted by the existing progress test.

Also record final convergence or retry request.

## Decision

Localize whether fail/pass separation begins in:

- the Newton linear update;
- constitutive response after the update;
- line-search progress criterion;
- or convergence criteria after an accepted update.

No repair is allowed in P1.