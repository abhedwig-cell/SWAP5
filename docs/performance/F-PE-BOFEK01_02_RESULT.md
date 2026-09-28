# F-PE-BOFEK01/02 screening result

Date: 2026-09-28

Status: `STRICT_SCREENING_COMPLETE_NO_ADVANCING_CANDIDATE`

Canonical authority:

`integration/f-ci-canonical@50ee9dc2acbc9847807d3fd98d0553f9862d428b`

Current evidence run:

GitHub Actions run `36413271282`, head `60f68c0a5ecf9da0926a33c485c8cb832826e62a`, SUCCESS.

## Scope exercised

The screening uses the admitted fixed-K dynamic-top `SWKIMPL=0` Reference surface and preserves the BOFEK00 correctness boundary.

The direct Reference harness was aligned to BALTOL02 before the final evidence run:

`effective balance-rate tolerance = max(1e-12 cm/day, 2.8e-16 cm / dt)`.

The repository currently has no complete BOFEK profile catalogue. The screening therefore uses four repository-backed difficult hydraulic archetypes (B01, B12, O05, O14) across five dry-to-ponding regimes. Sixteen cases are used for screening and four were preregistered as holdouts.

This supports numerical-policy screening. It does not support a BOFEK-ID-specific production mapping.

## Frozen advancement rule

A parameter can advance only when:

1. all strict physical gates pass on the screening bank; and
2. median deterministic solver-work reduction is at least 8%.

No post-hoc relaxation is allowed.

Primary work metric:

`nonlinear iterations + backtracks + Jacobian builds + linear solves`.

## Result by family

### Timestep envelope

No candidate advances.

- `DTMAX x0.5`: only 1/16 strict passes; median work is worse on passing cases.
- `DTMAX x2`: 0/16 strict passes.
- `DTMAX x4`: 1/16 strict passes; about 8.3% median work reduction only inside that surviving subset.
- `DTMIN x0.5`: 3/16 strict passes, no work gain.
- `DTMIN x2`: 3/16 strict passes, no work gain.
- initial `dt = DTMIN`: 5/16 strict passes, work worsens.
- initial `dt = 0.5*DTMAX`: 6/16 strict passes; about 8.6% median work reduction only inside that surviving subset.
- initial `dt = DTMAX`: 1/16 strict passes; about 19.4% work reduction only inside that surviving subset.

The apparent large-step speedups are therefore not strict Reference candidates. Their terminal head/runoff/ponding trajectories fail the frozen gates in most cases.

### Adaptation policy

No candidate advances.

- `NUMBIT_CRIT=2`: severe work regression.
- `NUMBIT_CRIT=3`: 5/16 strict passes, no work gain.
- `NUMBIT_CRIT=5`: 14/16 strict passes, exactly 0% median work reduction.
- `NUMBIT_CRIT=6`: 13/16 strict passes, exactly 0% median work reduction.
- increase-factor candidates `1.25, 1.5, 3.0`: fail the strict trajectory broadly and do not reduce deterministic work on the passing subset.
- accepted-step decrease `0.25, 0.75`: 15/16 strict passes, 0% median work reduction.
- failure-reduction divisors `1.5, 3, 4`: 14-15/16 strict passes, 0% median work reduction.

### Nonlinear effort

No candidate advances.

- `MAXIT=5`: 10/16 strict passes, 0% median work reduction.
- `MAXIT=6`: 14/16 strict passes, 0% median work reduction.
- `MAXIT=10,12`: 14/16 strict passes, 0% median work reduction.
- `max_backtracking=2,4,6`: all 16/16 strict passes, but deterministic work is unchanged.
- head-tolerance x10: 15/16 strict passes, median work reduction about 3.0%.
- head-tolerance x100: 14/16 strict passes, median work reduction about 6.2%.

The strongest nonlinear candidate still misses both requirements: it is below the frozen 8% work gate and fails strict runoff in two screening cases.

## Timing interpretation

Single-process wall-clock measurements in this screening are secondary only. Individual cases are too short for robust timing, and first-call/process effects are visible. No wall-clock speed claim is made from these ratios.

The deterministic solver-work result is sufficient for the advancement decision because no candidate reaches the preregistered work gate while preserving strict accuracy.

## Holdout decision

No candidate reached the preregistered advancement gate. Therefore no parameter set is eligible for interaction optimization or holdout qualification.

The four preregistered holdout cases remain unexposed for candidate selection. This is deliberate. Running a failed screening candidate on holdout would not rescue it and would violate the selection/validation separation.

## Scientific interpretation

On the corrected BOFEK00 wet Reference surface, the conservative timestep policy is not simply wasting large amounts of exact solver work that can be removed by a small global adjustment.

Aggressive timestep enlargement can substantially reduce solve count, but under STRICT Reference it changes the numerical trajectory beyond the frozen accuracy limits. Less aggressive controller changes mostly leave work unchanged.

The current evidence therefore does not justify a global, hydraulic-class or regime-aware strict production policy.

## Negative result retained

This workunit specifically rejects the following strict-production hypotheses within the tested authority:

- larger global `DTMAX` as a free speedup;
- a more aggressive initial timestep as a free speedup;
- higher `NUMBIT_CRIT` as a meaningful performance lever;
- simple change of growth/shrink/failure factors as a meaningful strict lever;
- lower/higher `MAXIT` as a meaningful strict lever;
- backtracking-cap tuning as a meaningful strict lever;
- broad head-tolerance relaxation as a >=8% strict lever.

## Next valid question

The data do show a clear speed/trajectory tradeoff for larger timesteps and looser head convergence. That belongs to a separately preregistered PRACTICAL / COUPLING accuracy mode, not to STRICT Reference.

Any BOFEK-class-specific production claim also requires a repository-owned BOFEK parameter/profile catalogue and a mapping from BOFEK classes to the exercised hydraulic descriptors.
