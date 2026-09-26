# F-PE-APPROX04 P1B — exact participant displacement frontier

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

P1A established that the exact transaction participant can reject a +0.05 cm corrector displacement even though the offline local q(h) approximation remains accurate there.

Therefore the surrogate validity envelope must be intersected with the exact participant admissibility envelope.

## Question

For each frozen difficult PROFILE06 origin, what prescribed-head displacement remains admissible to the exact mode-5 transaction participant?

## Cases

- B01 wet, h0 = -10 cm;
- B01 mid, h0 = -75 cm;
- B12 wet, h0 = -10 cm;
- O05 wet, h0 = -10 cm;
- O14 wet, h0 = -10 cm;
- O14 mid, h0 = -75 cm.

## Displacement grid

Fresh process per point.

Test signed offsets [cm]:

- 0;
- +/-0.001;
- +/-0.0025;
- +/-0.005;
- +/-0.010;
- +/-0.020;
- +/-0.050.

All other state, forcing and numerical controls remain fixed to the P1A-reconciled exact participant.

## Measurements

For every point report:

- participant trial status;
- valid response availability;
- exact q when available;
- exact tangent when available;
- solver status/iteration/retry diagnostics where exposed.

## Frontier rule

For each sign and case, define the admissible frontier as the largest tested absolute displacement for which the exact participant succeeds.

Do not interpolate beyond tested points.

## Decision

A response-surrogate prototype may advance only on an envelope that is inside the exact participant frontier for every selected case intended for common qualification.

If the common cross-case frontier collapses to zero or an operationally negligible displacement, reject APPROX04 rather than bypassing transaction authority.
