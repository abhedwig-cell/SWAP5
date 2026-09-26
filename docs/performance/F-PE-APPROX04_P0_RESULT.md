# F-PE-APPROX04 P0 result — offline same-origin response error

Date: 2026-09-26

Status: `POSITIVE_ADVANCE_TO_BOUNDED_PROTOTYPE`

## Scope

Exact mode-5 q(h) and response tangent were evaluated around six difficult PROFILE06 origins:

- B01 wet;
- B01 mid;
- B12 wet;
- O05 wet;
- O14 wet;
- O14 mid.

Offsets:

- 0;
- +/-0.05 cm;
- +/-0.10 cm;
- +/-0.25 cm;
- +/-0.50 cm.

Prediction:

`q_pred = q0 + tangent0 * delta_h`

## Full +/-0.50 cm window

Across all six cases:

- response orientation remained unchanged;
- worst error relative to exact q excursion: about 0.788%;
- worst tangent drift: about 1.573%.

The controlling case was O05 wet.

At +0.50 cm:

- q-excursion-relative prediction error: about 0.788%;
- relative tangent drift: about 1.573%.

This is small enough to justify research continuation, but the initial prototype does not need the full A1 tangent-cache window.

## Conservative +/-0.25 cm envelope

Within +/-0.25 cm, the controlling O05-wet case gives approximately:

- maximum response error relative to exact q excursion: 0.390%;
- maximum tangent drift: 0.779%;
- absolute q error: about 0.0135 cm/day.

Other difficult cases are materially smaller.

Examples at +/-0.25 cm:

- B01 wet: max excursion-relative error about 0.127%;
- O14 wet: max excursion-relative error about 0.227%;
- B01 mid, B12 wet and O14 mid: orders of magnitude smaller.

All tested cases preserve response orientation.

## Decision

P0 supports a bounded response-only prototype.

Initial P1 research envelope:

- same origin lineage/revision/window;
- absolute prescribed-head displacement <= 0.25 cm;
- maximum 8 surrogate corrector uses;
- exact fallback outside the envelope;
- exact final physical trial before any commit.

The 0.25 cm bound is intentionally stricter than A1's 0.5 cm tangent-cache bound.

No production surrogate is admitted by P0.
