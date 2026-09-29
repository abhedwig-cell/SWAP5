# F-PE-NLGLOB14Q result — first-retreat transactional shadow TG solve

Date: 2026-09-29

Status:

`NLGLOB14Q_FULL_COLUMN_TG_SHADOW_HANDOFF_ADMISSIBLE`

Qualification authority:

- workflow run: `36588192089`;
- job: `109474317758`;
- conclusion: SUCCESS.

## Frozen question

Can exactly one ordinary full-column provider-consistent TG interval be evaluated transactionally from the qualified first-retreat accepted state under the actual dry forcing and current surface-flux route, without committing the shadow result?

The persistent saturated-KLAG trajectory remains the accepted control.

## Coverage

PASS.

All 12 six-level O05 HEAD/RUNOFF fixtures:

- reach exactly one qualified first-retreat shadow origin;
- execute exactly one TG shadow interval;
- complete the ordinary TG acceptance path;
- remain finite;
- keep origin, predictor, endpoint and accepted-candidate route on surface-flux;
- report no solver retry;
- retain clean independent dry-phase shadow mass;
- rollback physical state and accepted accounting exactly;
- leave the persistent-KLAG control trajectory complete and mass-clean.

## Shadow solve result

All 12 fixtures classify:

`SHADOW_TG_INTERVAL_ADMISSIBLE`.

Aggregate classification:

`NLGLOB14Q_FULL_COLUMN_TG_SHADOW_HANDOFF_ADMISSIBLE`.

Representative shadow work is 3 to 4 nonlinear/Jacobian/linear solves for most fixtures. The two finest trajectories use 10 backtracking attempts while still converging without retry.

Independent shadow mass ledgers remain at roundoff scale, approximately a few `1e-15 cm`.

Rollback differences are zero within the exact diagnostics for:

- pressure head;
- water content;
- ponding;
- cumulative ledger;
- cumulative runoff.

## Saturation state after shadow

Every successful TG shadow candidate still contains:

`13 saturated nodes`.

Thus the shadow TG interval is numerically admissible even though the contiguous lower saturated block remains present.

No immediate predictor-domain saturation-event failure occurs in this single interval.

## Scientific interpretation

The first retreat event is not merely a formal TG-origin or predictor-admissibility point.

Under the existing provider regularization and the actual dry surface-flux forcing, one full-column TG interval can be solved successfully and conservatively from that state.

However, NLGLOB14Q does not establish stable persistent TG ownership.

The shadow candidate remains partly saturated, so the next question is whether committing that one TG interval and then continuing ordinary TG produces a stable desaturating trajectory or immediately causes saturation-event re-entry/chatter.

## Consequence

Open a separately preregistered test-only accepted handoff/re-entry falsification.

It must:

- commit exactly one qualified TG handoff interval at first retreat;
- preserve transactional accounting;
- continue under the unchanged dry forcing;
- permit the existing saturation-event machinery to re-enter saturated mode if physically triggered;
- record any immediate or repeated TG/saturated-mode chatter;
- compare against the persistent-KLAG control trajectory;
- preserve physical mass.

No production mode switch is authorized.

## Production boundary

Research only.

No production `src/**` change.

No numerical default or production temporal-mode ownership changed.

`LEGACY_NUMERICS` remains production default.
