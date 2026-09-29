# F-PE-NLGLOB14O result — first-retreat full-column TG handoff admissibility

Date: 2026-09-29

Status:

`NLGLOB14O_FULL_COLUMN_TG_HANDOFF_ORIGIN_ADMISSIBLE`

Qualification authority:

- workflow run: `36585663754`;
- job: `109465241511`;
- conclusion: SUCCESS.

## Frozen question

Is the first accepted 14 -> 13 retreat state a valid full-column origin for the currently qualified provider-consistent head-space TG mechanism under the existing constitutive provider contract?

No temporal-mode switch was performed.

## Coverage

PASS.

All 12 NLGLOB14N3 trajectories:

- complete;
- retain valid first-retreat brackets;
- remain finite and mass-clean;
- preserve constitutive theta/head consistency at the retreat handoff origin.

## Capacity result

At every first post-retreat origin:

- nodes 1:3 are unsaturated and have finite positive capacity;
- nodes 4:16 remain saturated;
- the current default-mVG provider nevertheless returns finite positive capacity for nodes 4:16.

Therefore all 12 fixtures satisfy the preregistered full-column positive-capacity gate.

Frozen classification:

`NLGLOB14O_FULL_COLUMN_TG_HANDOFF_ORIGIN_ADMISSIBLE`.

## Important provider attribution

The positive capacity on saturated nodes is not the physical unsaturated derivative approaching a finite positive limit.

Current provider authority is explicit:

for `h >= 0`,

`b110_moiscap = step_duration * 1e-7`.

Observed lower-block capacities therefore scale exactly with dt:

- dt 2.5e-4 d -> C = 2.5e-11;
- dt 1.25e-4 d -> C = 1.25e-11;
- ...
- dt 7.8125e-6 d -> C = 7.8125e-13.

Thus the positive NLGLOB14O gate establishes compatibility with the **existing regularized provider contract**, not proof that the saturated lower block has ordinary unsaturated constitutive capacity.

## Scientific interpretation

NLGLOB14O does not falsify whole-column handoff at the origin-capacity level.

But it also does not qualify a TG handoff solve.

The saturated lower block is made formally head-space-divisible by the existing dt-dependent capacity regularization. Because this capacity becomes extremely small under refinement, a finite physical moisture derivative may generate a very large head-space predictor increment.

Therefore the next necessary question is predictor admissibility under the actual dry-phase physical derivative.

## Consequence

Open a separately preregistered successor:

`F-PE-NLGLOB14P — first-retreat full-column TG predictor admissibility`.

At the same retreat origins, compute the accepted-state physical moisture derivative from the actual dry forcing and internal fluxes, then form the existing head-space predictor:

`h_tilde = h + dt * theta_dot / C`.

No solve or temporal-mode switch is authorized until that predictor is shown finite and physically admissible.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No numerical default or mode ownership changed.

`LEGACY_NUMERICS` remains production default.
