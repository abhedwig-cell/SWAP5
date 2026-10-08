# F-PE-NLGLOB14P closeout — first-retreat full-column TG predictor admissibility

Date: 2026-09-29

Final status:

`NLGLOB14P_FULL_COLUMN_TG_PREDICTOR_ADMISSIBLE`

Qualification authority:

- run `36586521705`;
- job `109468402329`;
- conclusion: SUCCESS.

## Closure

NLGLOB14P closes positively.

At all 12 qualified first-retreat origins, the existing provider-consistent full-column head-space TG predictor is finite and constitutively evaluable.

Observed across the frozen bank:

- max |h_dot| about `396.93 cm/d`;
- minimum h_tilde about `-24.12 cm`;
- maximum h_tilde about `130.00 cm`;
- minimum predicted conductivity about `5.31 cm/d`;
- worst |h_dot| occurs on node 1, not in the still-saturated lower block.

The persistent-KLAG control trajectories remain finite and mass-clean.

## Interpretation boundary

This is predictor admissibility only.

It does not establish:

- successful TG endpoint solve;
- accepted-state equivalence;
- safe temporal-mode release;
- absence of immediate re-entry;
- production readiness.

The positive result remains conditioned on the existing dt-dependent saturated-node capacity regularization described by NLGLOB14O.

## Direct successor

Open:

`F-PE-NLGLOB14Q — first-retreat transactional shadow TG solve`.

At the same accepted retreat origins, perform exactly one full-column TG shadow trial using the unchanged timestep and dry forcing.

Requirements:

1. begin from the exact accepted retreat-origin state;
2. use the existing provider-consistent TG mechanism;
3. never commit the shadow candidate;
4. restore accepted state and accounting exactly;
5. compare shadow solve status, route, mass diagnostics and candidate state against the persistent-KLAG control;
6. record whether ordinary TG would immediately encounter saturation/re-entry conditions.

No persistent mode switch is authorized.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14P

BRANCH: `research/f-pe-nlglob14p-full-column-tg-predictor`

STATUS: closed positive predictor admissibility

TEST STATUS: 12-case full-column predictor probe PASS

QUALIFICATION STATUS: `NLGLOB14P_FULL_COLUMN_TG_PREDICTOR_ADMISSIBLE`

NEXT SAFE STEP: preregister transactional shadow TG solve at first retreat.

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
