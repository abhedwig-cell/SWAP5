# F-PE-BALTOL01 historical authority reconciliation

Date: 2026-09-26

Status: `BOUND_TO_EXISTING_REFERENCE_NUMERICAL_AUTHORITY`

## Why this note exists

SHORTSTEP01 independently rediscovered a Reference balance-tolerance floor in the difficult coupled-corrector regime. The repository already contains earlier admitted publication-line authority on the same numerical family.

BALTOL01 therefore treats that evidence as prior authority rather than starting from a blank tolerance study.

## Existing authority

### PUB-P2E04

Established on the frozen P2E03 Reference matrix that:

- Reference HeadCalc residual and convergence criteria are native balance-rate quantities in cm/day;
- failure classes split into TOTAL_ONLY and dominant LOCAL_BAL;
- raising nonlinear iteration count through 64 did not resolve representative failures;
- loosening only total-balance tolerance recovered selected TOTAL_ONLY cases without changing accepted endpoint state;
- that diagnostic sensitivity did not authorize a production tolerance change.

### PUB-P2E06

Established for all 103 P2E04 LOCAL_BAL cases that:

- shorter dt greatly increases LOCAL_BAL failure frequency under the same absolute 1e-12 cm/day criterion;
- 101/103 retained exactly the same maximum residual when max iterations increased;
- failed-stage `dt * max|residual|` remains around 1e-16 to 1e-15 cm;
- the observed rate scaling is consistent with a numerical resolution/cancellation floor.

### PUB-P2E07

Reconstructed all 103 LOCAL_BAL residuals exactly from internal failed HeadCalc state and found:

- the preregistered estimated numerical floor is at or above the fixed 1e-12 cm/day compartment criterion in 102/103 failures;
- the estimated floor is dominated by theta input-representation scale in 103/103;
- higher-precision recomposition and summation-order effects are much smaller;
- no production tolerance or numerical-policy change was authorized.

## Relation to SHORTSTEP01

SHORTSTEP01 extends this existing authority into the newer dynamic-history, prescribed-head coupling regime.

Its new contribution is not the generic existence of a Reference numerical floor. It shows that the same class of floor can:

- create non-monotone single-step dt pass/fail bands in difficult mode-5 correctors;
- block the TEMPORAL03 fixed-substep oracle;
- cause hundreds of wasted backtracking attempts after the state is already near the numerical residual floor;
- disappear on representative targets when the numerical balance criterion moves from 1e-12 to 2e-12, with negligible state/flux change.

## BALTOL01 interpretation boundary

The P0 numerical ladder remains preregistered exactly as written.

However, candidate values are interpreted in cm/day, and a fixed `2e-12` production tolerance is not presumed to be the final policy.

The qualification must explicitly consider whether the scientifically correct successor is:

- a minimally relaxed fixed rate tolerance;
- a numerically scaled floor tied to representable state resolution;
- or a different convergence policy that avoids treating sub-resolution residual noise as physical nonconvergence.

Any policy decision must preserve the existing P2E04-P2E07 evidence and cannot weaken it retroactively.