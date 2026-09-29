# F-PE-NLGLOB14P result — first-retreat full-column TG predictor admissibility

Date: 2026-09-29

Status:

`NLGLOB14P_FULL_COLUMN_TG_PREDICTOR_ADMISSIBLE`

Qualification authority:

- workflow run: `36586521705`;
- job: `109468402329`;
- conclusion: SUCCESS.

## Frozen question

At the qualified first-retreat accepted state, is the existing full-column provider-consistent head-space TG predictor finite and constitutively admissible when evaluated from the actual dry-phase physical moisture derivative?

No TG solve and no temporal-mode switch were performed.

## Coverage

PASS.

All 12 six-level O05 trajectories:

- complete;
- retain valid first-retreat brackets;
- remain finite and mass-clean;
- preserve constitutive consistency at the handoff origin;
- retain the qualified NLGLOB14N3 root-controller behavior.

## Predictor result

All 12 full-column predictors satisfy the preregistered admissibility gates:

- provider capacity finite and >0 on all 16 nodes;
- physical theta_dot finite;
- h_dot finite;
- h_tilde finite;
- conductivity evaluated at h_tilde finite and >0.

Frozen classification:

`NLGLOB14P_FULL_COLUMN_TG_PREDICTOR_ADMISSIBLE`.

Observed envelope across all fixtures:

- max |h_dot| about `396.93 cm/d`;
- minimum h_tilde about `-24.12 cm`;
- maximum h_tilde about `130.00 cm`;
- minimum predicted conductivity about `5.31 cm/d`.

The worst |h_dot| node is node 1 in every fixture, not a node in the still-saturated lower block.

## Important interpretation

The positive predictor result is under the existing provider contract, including the dt-dependent saturated-node capacity regularization established in NLGLOB14O.

NLGLOB14P therefore establishes that the regularized full-column TG predictor is numerically well-defined at first retreat.

It does not establish that a TG endpoint solve from that origin converges, preserves mass, or provides safe temporal-mode ownership.

## Consequence

Open a separately preregistered transactional shadow TG solve from the same first-retreat accepted origins.

The shadow solve must:

- begin from exactly the accepted retreat-origin state;
- use the unchanged physical forcing and timestep;
- never commit its candidate state;
- restore accepted state/accounting exactly;
- compare solve status, route, mass and candidate state against the persistent-KLAG control;
- fail closed on solver retry/failure, route inconsistency, nonfinite state or mass discontinuity.

No production release switch is authorized by NLGLOB14P.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No numerical default or temporal-mode ownership changed.

`LEGACY_NUMERICS` remains production default.
