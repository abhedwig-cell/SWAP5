# F-PE-NLGLOB13B result — bounded second-level near-saturation subdivision

Date: 2026-09-29

Status:

`CLOSED_TG_NEARSAT_SUBDIV4_INSUFFICIENT`

Canonical base:

`integration/f-ci-canonical@5c498c9df933f900fd00869b72106584f10f6622`

Qualification authority:

- workflow run: `36555644418`;
- job: `109364015914`;
- conclusion: SUCCESS.

## Frozen candidate

NLGLOB13B allowed at most two subdivision levels for TG near-saturation accepted-state admissibility:

- nominal `h`;
- failing nominal trial split to `h/2`;
- a failing `h/2` child could be replaced by two `h/4` intervals;
- no subdivision below `h/4`.

Only accepted-state retention-domain failure could trigger subdivision.

The NLGLOB11A head-space endpoint coefficient stage and S0 replay remained unchanged.

## Smooth preservation bank

PASS.

- median refined top-head order: `2.04787`;
- median refined top-theta order: `2.04787`;
- median work ratio versus KLAG BE: `1.0`.

The smooth second-order authority is preserved.

## Near-saturation target bank

All seven target trajectories reach the second subdivision level:

- target cases: 7;
- target cases with level-1 split, producing `h/4`: 7/7;
- completed target trajectories: 0/7.

Thus moving from `h/2` to `h/4` does not restore accepted-state retention admissibility.

## Full dynamic bank

Completed requested horizon:

`79 / 96 = 0.82292`.

Physical mass remains near roundoff:

- max accepted-interval ledger about `4.84e-14 cm`;
- max cumulative ledger about `6.06e-14 cm`.

Other diagnostics:

- process failures: 0;
- maximum allowed subdivision depth respected: PASS;
- total subdivision events: 14;
- second-level subdivision events: 7.

The classifier records 11 terminal domain-family failures in the full bank.

## Frozen classification

`CLOSED_TG_NEARSAT_SUBDIV4_INSUFFICIENT`.

The bounded second-level subdivision candidate does not qualify.

## Interpretation

The remaining near-saturation failure is not a simple coarse-step artifact over the tested `h`, `h/2` and `h/4` hierarchy.

Both one-level and two-level temporal subdivision preserve smooth order and physical mass, but neither makes the seven target accepted TG states admissible.

Blindly continuing to `h/8` would therefore be post-hoc depth tuning and is not authorized.

The next scientific question is whether the out-of-domain accepted moisture is converging toward the saturation bound as dt decreases, or whether the temporal solution genuinely requires storage beyond the current incompressible `theta_s` constitutive ceiling.

That distinction should be resolved observationally before another temporal method is proposed.

## Consequence

Open a separately preregistered saturation-bound scaling attribution.

Measure, on the failed target substeps:

- accepted-origin distance to `theta_s`;
- prospective accepted TG overshoot `theta_TG-theta_s`;
- overshoot in physical water-depth units;
- dependence on substep duration across `h`, `h/2`, and `h/4`;
- whether the direction is consistent with vanishing temporal error or with physically positive saturated storage demand.

No deeper subdivision is authorized by NLGLOB13B.

## Production boundary

Research only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
