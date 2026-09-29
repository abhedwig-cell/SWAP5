# F-PE-NLGLOB14M result — first saturated-block retreat event localization

Date: 2026-09-29

Status:

`NLGLOB14M_FIRST_RETREAT_EVENT_LOCALIZED`

Canonical base:

`integration/f-ci-canonical@246eca153a7846c07e4981a07c6498528b771ee5`

Qualification authority:

- workflow run: `36569300490`;
- job: `109408977563`;
- conclusion: SUCCESS.

## Frozen question

Can the first saturated-block retreat be localized as a physical saturation-boundary event with timestep-convergent timing, without introducing a release switch?

## Coverage

PASS.

All 8 frozen O05/TG extended-dry fixtures:

- complete the full horizon;
- retain finite, mass-clean states;
- preserve saturation-indicator consistency;
- provide a valid retreat event bracket;
- identify the same retreat node: node 3.

Process failures:

`0`.

## Event definition

For each fixture:

- A = final accepted state with the attained maximum saturated-block extent;
- B = immediately following accepted state where the retreat node is unsaturated;
- A has h >= 0 and theta = theta_s;
- B has h < 0 and theta < theta_s.

The physical event boundary is therefore the existing saturation boundary:

`h_3 = 0`.

No empirical pressure threshold is used.

## Linear root estimates

HEAD route family:

- dt 2.5e-4 d: t_root ≈ 0.02197395 d;
- dt 1.25e-4 d: t_root ≈ 0.02209077 d;
- dt 6.25e-5 d: t_root ≈ 0.02185228 d;
- dt 3.125e-5 d: t_root ≈ 0.02173074 d.

RUNOFF route family:

- dt 2.5e-4 d: t_root ≈ 0.02626787 d;
- dt 1.25e-4 d: t_root ≈ 0.02633392 d;
- dt 6.25e-5 d: t_root ≈ 0.02618443 d;
- dt 3.125e-5 d: t_root ≈ 0.02610869 d.

## Frozen convergence test

Both route families satisfy the preregistered convergence signal.

HEAD:

- D_mid ≈ 2.3849e-4 d;
- D_fine ≈ 1.2154e-4 d;
- D_fine <= D_mid: PASS;
- D_fine <= 2*6.25e-5 d: PASS.

RUNOFF:

- D_mid ≈ 1.4948e-4 d;
- D_fine ≈ 7.5741e-5 d;
- D_fine <= D_mid: PASS;
- D_fine <= 2*6.25e-5 d: PASS.

## Physical admissibility

Physical mass remains near roundoff:

- max interval ledger about `2.36e-14 cm`;
- max cumulative ledger about `2.71e-14 cm`.

All event brackets are finite and indicator-consistent.

## Frozen classification

`NLGLOB14M_FIRST_RETREAT_EVENT_LOCALIZED`.

All frozen gates pass.

## Scientific interpretation

The first retreat of the saturated lower block is a reproducible physical event associated with the retreat node crossing the saturation boundary h=0.

This is materially stronger than an empirical release threshold:

- the event follows directly from the existing saturation state definition;
- the event timing is bracketed by accepted states;
- root estimates show refinement convergence in both forcing families.

## Consequence

A separately preregistered test-only release experiment is authorized.

That experiment may switch persistent saturated temporal mode only at the localized first-retreat event and must prove:

- transactional state continuity;
- physical interval and cumulative mass closure;
- no immediate release/re-entry chatter;
- finite route-consistent accepted states;
- smooth TIMEINT16C second-order authority remains unchanged when the release event is inactive.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No release switch or numerical default changed.

`LEGACY_NUMERICS` remains production default.
