# F-PE-NLGLOB11 closeout — TG coefficient-stage predictor admissibility

Date: 2026-09-29

Final status:

`CLOSED_TG_SAT_EXTENSION_PHYSICAL_ADMISSIBILITY_FAILED`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@6ce07b5578c0c1193d2d21a2449a1b7788714f40`

Qualification authority:

- run `36551065621`, job `109349078694`, SUCCESS;
- result-head rerun `36551202545`, SUCCESS.

## Closure

NLGLOB11 closes the saturated auxiliary coefficient-stage extension negatively.

The extension successfully removes the seven original `PREDICTED_RETENTION_DOMAIN_FAILED` exits and leaves the smooth TIMEINT16C second-order authority unchanged:

- median refined top-head order about 1.99755;
- median refined top-theta order about 1.99755;
- 4/4 individual head orders >=1.5;
- physical/cumulative mass at roundoff;
- median work ratio versus KLAG BE 1.0.

However, the same seven O05 TG HEAD/RUNOFF trajectories subsequently fail the exact accepted TG retention roundtrip.

Therefore the auxiliary predictor overshoot is not merely a coefficient-evaluation representation issue. In this near-saturated dynamic-top subset the unchanged full-step TG accepted moisture construction can itself leave the constitutive domain.

## Scientific consequence

Do not repair this by accepted-state clipping.

Do not reinterpret saturation projection as physical acceptance.

A future TG near-saturation successor must alter the temporal construction before acceptance, for example through a separately preregistered bounded substep/event-local construction, while retaining:

- exact physical accepted-interval mass;
- current-step/provider-consistent K staging;
- smooth second-order authority;
- constitutively admissible accepted moisture/head;
- no hidden history mass.

## Parallel blocker

The separate 14 post-replay endpoint failures remain owned by NLGLOB12. They are above the balance/storage floor and are not part of this TG predictor closeout.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards endpoint robustness

WORK UNIT: F-PE-NLGLOB11

BASELINE: `6ce07b5578c0c1193d2d21a2449a1b7788714f40`

BRANCH: `research/f-pe-nlglob11-tg-predictor-admissibility`

STATUS: closed negative

IMPLEMENTATION STATUS: test-only auxiliary saturation-stage extension persisted

TEST STATUS: focused dynamic-top and TIMEINT16C order runs PASS

QUALIFICATION STATUS: `CLOSED_TG_SAT_EXTENSION_PHYSICAL_ADMISSIBILITY_FAILED`

DEPENDENCIES / BLOCKERS: near-saturation TG temporal construction remains unresolved; NLGLOB12 separately owns above-floor endpoint failures

NEXT SAFE STEP: admit this negative authority; continue NLGLOB12 independently

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
