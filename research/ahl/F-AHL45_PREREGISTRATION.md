# F-AHL45 — direct-demand architecture screen

Date: 2026-09-25

Status: `PREREGISTERED_SCREEN`

Parent performance finding: F-AHL44 closed current policy-4 lookup as speed-negative against the demand-specialized analytical provider.

## Question

Can a radically simpler generated theta(h) representation beat the current analytical theta-only demand while retaining enough accuracy to justify a derivative-consistent follow-up?

## Candidate

Research-only decade-segment direct table:

- domain |h| = 1 .. 1e6 cm;
- six decade segments;
- uniform spacing in physical |h| inside each decade;
- decade selected by fixed threshold branches;
- index computed directly from |h| and precomputed inverse spacing;
- theta stored directly;
- linear interpolation for this screening only;
- no log/log10;
- no binary search;
- no Hermite basis;
- no logistic reconstruction;
- analytical source remains authority outside domain.

This is **not** an admissible final hydraulic representation because C is not yet derived from the same smooth interpolant and derivative quality is not qualified.

## Screen

Test B01 and O05 authority parameters.

For 32, 64, 128 and 256 intervals per decade report:

- max absolute theta error over dense log-spaced validation;
- theta-span normalized max error;
- direct theta-demand cost at N=60;
- analytical theta-demand cost at the same N.

Decision:

- if no candidate is clearly faster than analytical, close the architecture;
- if a candidate is materially faster and theta error is promising, open a derivative-consistent C follow-up;
- no production source changes from this screen.
