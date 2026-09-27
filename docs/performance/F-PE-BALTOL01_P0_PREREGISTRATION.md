# F-PE-BALTOL01 P0 — broad dynamic Reference tolerance matrix

Date: 2026-09-26

Status: `PREREGISTERED_QUALIFICATION`

## Purpose

Test whether the factor-two recovery observed in SHORTSTEP01 is robust across the full difficult dynamic-origin set rather than being specific to three hand-picked failures.

## Matrix

Origins:

- B01 wet;
- B01 mid;
- B12 wet;
- O05 wet;
- O14 wet;
- O14 mid.

History directions:

- -10% top/bottom flux imbalance;
- +10% top/bottom flux imbalance.

Corrector offsets:

- -0.001 cm;
- +0.001 cm;
- -0.01 cm;
- +0.01 cm.

Single-step durations:

- 1e-4 day;
- 5e-5 day;
- 2.5e-5 day;
- 1.25e-5 day;
- 6.25e-6 day.

Balance tolerance arms, applied identically to compartment and total balance:

- 1e-12;
- 2e-12;
- 5e-12;
- 1e-11;
- 1e-10.

Total: 1200 certificate-free Reference-floor points.

## Fixed controls

- Reference Richards physical solver;
- mode-5 prescribed head;
- max nonlinear iterations 48;
- max backtracking 16;
- min step 1e-10 day;
- head tolerances unchanged at 1e-12;
- identical dynamic physical origin for tolerance arms of a point;
- no temporal certificate.

## Measurements

For every point:

- floor status and sample validity;
- nonlinear iterations and backtracking attempts;
- mass completeness and residual;
- terminal pressure-head and water-content vectors;
- terminal bottom flux.

## Primary comparison

For each physical point, identify the strictest successful tolerance arm.

Compare every looser successful arm with that strictest successful arm:

- max |dh|;
- max |dtheta|;
- terminal flux difference.

## Advancement gate

`2e-12` advances as the preferred minimal candidate only if:

- it recovers a material fraction of the 1e-12 failures across multiple origins/regimes;
- it does not lose any point that succeeds at 1e-12;
- overlapping accepted states and fluxes are equal or differ only at negligible numerical scale;
- mass accounting remains complete.

If 2e-12 is insufficient broadly, retain the smallest arm satisfying the same criteria for P1.

No production source change is allowed.