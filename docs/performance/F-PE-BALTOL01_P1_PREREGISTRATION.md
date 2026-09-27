# F-PE-BALTOL01 P1 — integrated-depth numerical-floor scaling

Date: 2026-09-26

Status: `PREREGISTERED_QUALIFICATION`

## Trigger

P0 shows that a fixed rate tolerance must rise to 1e-10 cm/day to complete all 240 difficult dynamic physical points, and that the remaining failures at 1e-11 are confined to the smallest tested dt.

Admitted PUB-P2E07 authority independently found that the dominant estimated Reference numerical floor is tied to theta input representation and that `dt * estimated_floor` spans approximately 2.8e-16 to 1.1e-15 cm.

## Hypothesis

A convergence floor expressed as an integrated-depth resolution scale is more numerically coherent than one fixed rate tolerance across dt.

Test:

`tol_rate = max(1e-12 cm/day, floor_depth / dt)`

## Arms

Fixed controls:

- FIXED_1E12: 1e-12 cm/day;
- FIXED_1E10: 1e-10 cm/day.

Integrated-floor candidates:

- DEPTH_2P8E16: floor_depth = 2.8e-16 cm;
- DEPTH_5E16: floor_depth = 5e-16 cm;
- DEPTH_1P1E15: floor_depth = 1.1e-15 cm.

Apply the derived rate tolerance identically to compartment and total balance gates.

## Matrix

Use the exact same 240 physical points as P0:

- six difficult origins;
- both +/-10% dynamic histories;
- offsets +/-0.001 and +/-0.01 cm;
- dt = 1e-4, 5e-5, 2.5e-5, 1.25e-5 and 6.25e-6 day.

## Measurements

- completion/pass set;
- derived rate tolerance;
- nonlinear iterations and backtracking;
- mass completeness/residual;
- terminal state and bottom flux.

For every successful arm compare with the strictest successful arm for the same physical point.

## Advancement gate

A scaled policy may advance only if it:

- loses no FIXED_1E12 success;
- materially recovers strict failures across dt;
- preserves state/flux to negligible numerical differences;
- preserves complete mass accounting;
- behaves consistently with the P2E07 integrated numerical-floor authority.

Completing all points is desirable but not sufficient by itself.

No production source change is allowed.