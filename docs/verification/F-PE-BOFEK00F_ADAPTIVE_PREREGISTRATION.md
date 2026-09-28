# F-PE-BOFEK00F — adaptive wet qualification addendum

Date: 2026-09-28

Status: **PREREGISTERED BEFORE QUALIFICATION LADDER**

Canonical authority: `integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`.

Correction-candidate preimage at preregistration:
`work/f-pe-bofek00-correction-candidate@11eb4e5f4a61674976789d9ede7bd8bb941a50b6`.

## Purpose

Characterize the interaction between the confirmed wet-regime correctness correction and the existing automatic transaction/timestep policy without changing that policy.

The adaptive production-shaped attempts already made at 172.8 s and 8.64 s are treated as exploratory diagnostics only. They are not used to choose a passing qualification duration.

## Frozen qualification ladder

Use exactly these requested interval durations, all from the same committed wet origin and forcing:

- 10 s
- 20 s
- 40 s
- 80 s
- 160 s
- 320 s

The ladder is geometric and anchored on the existing F-ROMV2-D21 10 s wet-boundary scale. No duration may be inserted, removed, shifted or interpolated after observing old-versus-corrected outcomes.

For every duration, run both:
1. current-authority solver preimage `0b67e2af993f16e9d1678b70cacfe9b164954140`;
2. corrected solver candidate from the same BOFEK00 lineage.

## Frozen policy

Both variants use exactly:

- temporal mode: `TX_TEMPORAL_EXTERNAL_FULL_HALF`;
- temporal tolerance: `1e-6`;
- mass tolerance: `1e-10`;
- retry scale: `0.5`;
- maximum retries per committed substep: `8`;
- maximum committed substeps: `256`;
- no model temporal-indicator budget.

Richards numerical settings, forcing, soil profile and boundary conditions remain identical between variants.

No DTMIN, DTMAX, NUMBIT_CRIT, growth/decrease factor, convergence criterion or tolerance is tuned in this work unit.

## Measurements

For each old/corrected run retain at minimum:

- completion/commit status;
- accepted substep count;
- attempts/retries where exposed;
- nonlinear iterations;
- internal solver retries;
- HeadCalc calls;
- Jacobian builds;
- linear solves;
- backtracks;
- alternative-solver calls;
- accepted mass residual;
- total water in;
- total water out;
- wall-clock runtime as informational PERFORMANCE evidence only.

With bottom flux fixed to zero and ET, drainage, root extraction, irrigation, snowmelt and runon zero, accepted `total_out` is the integrated surface runoff for this bounded fixture.

If the existing public application result does not expose the exact accepted-dt sequence, the qualification must not invent one. It may report accepted substep count and the controller retry ladder; exact dt-distribution remains an evidence limitation unless obtained through an existing diagnostic seam without production ABI change.

## Classification

- Differences in convergence, retry behavior or accepted timestep partition under identical policy are **adaptive interaction caused by solver correctness**, not a new timestep policy.
- Runtime differences are **PERFORMANCE** only.
- Any later change to timestep policy is a separate `NUMERICAL_POLICY` work unit.
- A correction is not rejected merely because a different correct trajectory partition changes integrated runoff. Such a difference must be quantified and explained against the frozen-timestep result.

