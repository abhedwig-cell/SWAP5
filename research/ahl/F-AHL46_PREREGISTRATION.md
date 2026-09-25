# F-AHL46 — direct-index derivative-consistent Hermite screen

Date: 2026-09-25

Status: `PREREGISTERED_SCREEN`

Parent: F-AHL45 direct-demand screen.

## Question

Can the fast direct-decade indexing discovered in F-AHL45 be combined with a derivative-consistent theta/C interpolant that remains materially faster than current analytical demand?

## Candidate

Research-only cubic Hermite representation in physical |h|:

- six decade segments over |h| = 1 .. 1e6 cm;
- uniform nodes per decade;
- fixed threshold decade selection;
- direct index arithmetic;
- node values store theta and exact analytical dtheta/dh;
- cubic Hermite theta interpolation;
- C is evaluated as the exact derivative of the same cubic interpolant;
- no log10, no binary search, no logistic reconstruction.

Because x=|h|=-h on the represented negative-head domain, Hermite slopes with respect to x are -C.

## Screen

Materials: B01 and O05.

Intervals per decade: 64, 128, 256.

Report:

- max absolute theta error on dense log-spaced validation;
- max absolute C error;
- max relative C error where analytical C >= 1e-13;
- theta-only runtime at N=60;
- theta+C runtime at N=60;
- analytical theta-only runtime;
- analytical theta+C runtime.

No production source change.

A follow-up is justified only if a candidate is both derivative-consistent by construction and clearly faster than the current demand-specific analytical provider.
