# F-PE-APPROX04 P1A result — offline response envelope versus transaction authority

Date: 2026-09-26

Status: `OFFLINE_ENVELOPE_TOO_WIDE_FOR_EXACT_PARTICIPANT`

## Finding

P0 showed that the local mode-5 q(h) response is nearly linear over a +/-0.25 cm window on the six difficult PROFILE06 origins.

P1A then moved the same hydraulic states into the real FGC44 transaction participant.

The fixture was reconciled to P0/PROFILE06 before interpretation:

- committed pressure-head profile = uniform h0;
- hydraulic material = same B01/B12/O05/O14 parameterization;
- predictor forcing = exact B1.10 `-K(h0)`;
- no A1 or A2C approximation needed for the exact-arm check.

With those authorities aligned, the exact participant still rejected the first B01-wet positive corrector displacement in the proposed sequence with participant status 6.

The rejected displacement was:

`+0.05 cm`

which is already much smaller than the proposed +/-0.25 cm surrogate envelope.

## Interpretation

This does not invalidate P0 as a local response characterization.

It shows that two envelopes are distinct:

1. local q(h) approximation accuracy;
2. exact production transaction admissibility.

A surrogate must satisfy both.

Therefore P1 may not use the P0 +/-0.25 cm window as its transaction envelope.

## Decision

Reject the initial P1A displacement envelope.

Before any surrogate timing or live coupling prototype, measure the exact participant admissibility frontier around the six difficult origins.

The next experiment varies only prescribed-head displacement and records exact participant PASS/FAIL.

No production code change is allowed.
