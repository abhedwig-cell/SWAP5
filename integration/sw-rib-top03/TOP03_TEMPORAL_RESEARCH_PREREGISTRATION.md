# TOP03 temporal route reassessment

Status: PREREGISTERED_RESEARCH_ONLY
Date: 2026-10-01
Branch baseline: 0060de2f0bb8bedd4880afcef6c74cb4afaaa9d3
Canonical inspected: 19f09b818b1bb30c1428919074c00098dbd062bd

Do not change production temporal acceptance yet. Investigate whether fixed-grid refinement of real imposed-head Richards solves converges in water profile and integrated surface transfer. Full/half is an investigation instrument, not selected production policy.

Use the existing four-node FSI/FAPP stub geometry and TOP03 fixture constitutive parameters, bottom mode 7 and constant initial-conductivity bottom flux. This is a shallow synthetic column, not field or live Ribasim qualification. Factorial cases: initial head -123 or -10 cm; initial pond 0 (onset) or 0.02 cm (continued imposed boundary, not a pre-equilibrated wet profile). External head 0.02 cm and sill 0.01 cm remain constant over 0.25 day. Equal subdivisions 1 through 512. The same physical initial state is restored for every grid.

Each converged solve materializes signed transfer only afterward. Reject positive qtop for the bounded experiment. Retain integrated soil mass hard oracle 1e-10 cm and surface closure 1e-12 cm; total whole-interval ledger is reported independently. Record failures rather than tune physics or waive acceptance. Report endpoint head/theta, transfer, first-substep transfer, iterations and local CPU time under O0/O2. Timing is descriptive only. Compare successive grids and a finest-grid reference; finest grid is not assumed ground truth. Inspect absence of convergence and roundoff floors before selecting a norm or accuracy budget.

The driver propagates solver candidates within an isolated research integration only. It does not call kernel commit, create a production candidate or publish receipts. Production acceptance remains unchanged. New nonlinear or boundary defects discovered here must be distinguished from temporal-policy defects. No broad Actions run is needed.
