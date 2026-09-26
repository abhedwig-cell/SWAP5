# F-PE-SHORTSTEP01 closeout — Reference Richards short-duration convergence pathology

Date: 2026-09-26

Status: `CLOSED_TOLERANCE_FLOOR_CAUSALITY_CONFIRMED`

## Question

Why do certificate-free Reference-floor solves from identical dynamic origins show non-monotone PASS/FAIL bands as step duration decreases?

## Answer

The observed bands are caused by an absolute balance-convergence floor at the research fixture's `1e-12` compartment and total balance tolerances.

The failed runs are not physically divergent and are not blocked by the pressure-head convergence criterion.

Representative failures reach residuals at roughly the same 1e-12 scale and then exhaust Newton/backtracking iterations because one balance gate remains marginally active.

## Evidence chain

### P0

Mapped 32 dynamic-origin duration ladders and confirmed non-monotone convergence bands including PASS→FAIL→PASS patterns.

### P1

Localized failing paths to near-tolerance line-search stagnation:

- successful neighbors converge in 3–5 Newton iterations;
- failing points use 48 iterations and hundreds of rejected backtracking trials;
- terminal residual maxima are already about 1e-12.

### P2

Direct convergence-gate instrumentation showed:

- head-change gate passes at the terminal failed state;
- O14's representative failure has zero per-compartment balance failures but fails only because total residual sum is `1.000755e-12` versus a `1e-12` threshold;
- B01 and O05 additionally have one compartment marginally above the same absolute threshold.

### P3

Changing only compartment and total balance tolerances from `1e-12` to `2e-12` converts all three representative fail targets into fast successful solves.

Accepted physical differences across the successful tolerance arms are negligible:

- head differences at or below about `3.6e-14 cm`;
- water-content differences around machine precision;
- terminal-flux differences at or below about `8.9e-12 cm/day`.

## Scientific interpretation

The TEMPORAL03 oracle blocker is not evidence of an inherent short-duration Richards instability.

It is a numerical tolerance-policy artifact in the qualification fixture: an extremely strict absolute balance criterion interacts with floating-point residual floors and line-search progress tests.

This also explains why tiny changes in dt produce apparently irregular PASS/FAIL bands: neighboring dt values can terminate on opposite sides of an absolute threshold without materially different physical states.

## Decision

SHORTSTEP01 closes diagnostic-only.

No production `src/**` change is admitted here.

The refined temporal oracle can potentially be recovered once a qualified Reference balance-tolerance policy is available.

## Required successor

`F-PE-BALTOL01 — Reference Richards balance-tolerance qualification`

The successor should:

- establish a physically and numerically justified lower bound for compartment and total balance tolerances;
- compare `1e-12`, `2e-12`, `5e-12`, `1e-11`, `1e-10` and any production-relevant settings across broader difficult cases;
- quantify state, flux, integrated mass and runtime effects;
- verify recovery of the TEMPORAL03 8/16/32 fixed-substep oracle;
- distinguish a fixture-only correction from any production default change;
- admit no production change until reference accuracy is independently preserved.