# F-PE-APPROX03 measurement plan

Date: 2026-09-26

Status: `OBSERVATION_AND_CONTROLLED_EXPERIMENTS`

Parent:
`F-PE-APPROX02@5525971b20c07fad87e536aa45fa245eff1c84ff`

## Objective

Determine whether temporal refinement / accepted-substep effort remains a material runtime source after A1 and A2C.

No production temporal setting changes are admitted in advance.

## Phase 1 — workload discovery

Identify production-shaped transient cases where the exact reference performs more than one accepted substep or otherwise incurs temporal refinement/retry work over a requested interval.

A useful discovery case must:

- converge under exact/default numerical settings;
- have complete canonical mass accounting;
- require more temporal work than a single direct accepted solve;
- be reproducible across runs.

Equilibrium or one-substep cases are not sufficient evidence for temporal approximation.

## Discovery dimensions

Search the existing B01/B12/O05/O14 wet/mid/dry material matrix across:

- requested interval duration;
- forcing contrast;
- temporal head budget;
- production bottom-boundary modes already admitted.

Do not alter constitutive physics.

## Phase 2 — first temporal lever

After a multi-substep workload is found, vary only one temporal control.

Preferred first axis:

`model_temporal_indicator_budget`

Keep:

- A2C either explicitly OFF for the baseline frontier or explicitly ON as a separate reference arm;
- local Richards tolerances otherwise fixed;
- retry scale unchanged;
- transaction mass tolerance unchanged;
- constitutive physics unchanged.

## Candidate budget sweep

Relative to the exact reference temporal budget `B`, test research-only multipliers where meaningful:

- `1x`;
- `2x`;
- `4x`;
- `8x`.

If the production budget is zero or not the active limiting mechanism, stop and classify the actual temporal limiter before choosing another control.

## Metrics

### Work
- accepted substeps;
- retries / rejected attempts;
- nonlinear iterations;
- Jacobian builds;
- linear solves;
- backtracking attempts;
- wall-clock runtime.

### Hydrological trajectory
- maximum pressure-head error;
- final pressure-head error;
- maximum water-content error;
- final water-content error;
- maximum bottom-flux error;
- cumulative bottom-exchange error;
- storage change.

### Accounting
- canonical mass residual;
- cumulative net-flow difference;
- cumulative storage difference.

## Advancement rule

Advance a temporal candidate only if it demonstrably removes temporal work and yields a reproducible runtime gain.

A candidate that changes a tolerance but leaves accepted substeps/retries unchanged is not evidence for a temporal optimization.

## Coupled gate

Any temporal candidate selected from local/multistep evidence must later pass a replicated live SWAP + MODFLOW6 gate before production admission.

## Default authority

Exact current temporal behavior remains default and authority.
