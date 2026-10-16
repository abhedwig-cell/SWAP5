# F-PE-DIR01 Repair05 preregistration — fused base constitutive value + direction

Date: 2026-09-26

Status: `PREREGISTERED_EXPERIMENT_ONLY`

Evidence authority:
- post-Repair03 profiling still shows directional constitutive work as one of the largest local directional costs;
- the accepted-step directional service currently performs a base-state conductivity value pass and then a second pass over the same pressure heads for exact directional constitutive derivatives;
- Repair04 showed that shrinking attempt-context payload is not material enough.

## Exact hypothesis

For the default B1.10 MvG provider, the directional service currently does:

1. `evaluate_demand(... CONDUCTIVITY ...)` at the accepted-step base pressure head to obtain the exact frozen K values used by the tangent assembly;
2. `evaluate_b110_default_mvg_state_direction(...)` over the same base pressure head to obtain:
   - dtheta/dh * dh;
   - dK/dh * dh;
   - smooth-branch qualification.

These two passes duplicate retention-branch evaluation and power arithmetic.

A fused default-MvG directional capability can calculate:
- exact base conductivity K;
- water-content direction;
- conductivity direction;
- the same smooth-route availability,

in one node loop.

## Experiment boundary

Before any production edit:

- add a test-local fused default-MvG routine;
- use it only for `b110_default_mvg_provider_t`;
- retain the current direct-retention route unchanged;
- retain current dynamic-top, source/sink, linear backsolve and transaction behavior;
- compare fused outputs bitwise or at the strictest existing directional tolerance against the current two-pass route.

The experiment may not change the physical solve or its constitutive provider.

## Required preservation

Require:
- identical physical checksum;
- identical accepted bottom-exchange derivative;
- identical final direction publication;
- identical accepted-step and backsolve counts;
- identical nonlinear/Jacobian/linear diagnostics;
- same smooth/nonsmooth fail-closed decisions for the production matrix used by the existing directional qualification;
- no effect on the non-directional route.

For base conductivity, the fused K must agree exactly with the existing default-MvG value provider on the qualified smooth route. If exact agreement cannot be demonstrated, reject the repair.

## Performance admission

Production admission requires:
- stable paired same-postimage timing improvement;
- the removed standalone conductivity pass is demonstrated by call-count or profiling evidence;
- preservation gates pass across representative wet/mid/dry default-MvG cases.

No claim from a microbenchmark alone is sufficient.
