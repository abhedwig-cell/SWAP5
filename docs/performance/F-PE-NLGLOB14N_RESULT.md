# F-PE-NLGLOB14N result — refined first-retreat event-time convergence

Date: 2026-09-29

Status:

`BLOCKED_NLGLOB14N_REFINED_RETREAT_CONVERGENCE`

Canonical base:

`integration/f-ci-canonical@a0295af615d04ec9a1b7653c92bef829bd6159ce`

Canonical authority rechecked before result persistence:

`integration/f-ci-canonical@ade0dc74638dd3f7e608a55947fdd2e928e883d8`

The intervening canonical delta is ELASTIC25-only and does not alter the NLGLOB14N temporal/event dependency surface.

Qualification authority:

- workflow run: `36569762769`;
- diagnostic rerun with unchanged frozen classifier: `36570032078`;
- latest job: `109411452773`;
- conclusion: SUCCESS.

## Frozen question

Does the unchanged node-3 retreat-event estimator converge when two finer dt levels are added?

## Coverage result

The full six-level ladder does not complete.

RUNOFF:

- all six brackets valid;
- finest-pair event-time difference ≈ `4.2262e-6 d`;
- frozen threshold = `1.5625e-5 d`;
- improves over NLGLOB14M finest-pair difference;
- route-family convergence signal: PASS.

HEAD:

- first five dt levels complete and bracket the same node-3 retreat event;
- finest dt `7.8125e-6 d` does not reach the retreat phase;
- terminal reason: `SATURATION_ROOT_TRIAL_OTHER_FAILED`;
- stop occurs at step 82;
- state remains finite;
- physical mass remains closed;
- no retreat bracket is available at that finest level.

Therefore the preregistered coverage gate fails.

## Frozen classification

`BLOCKED_NLGLOB14N_REFINED_RETREAT_CONVERGENCE`.

This is a coverage blocker, not a negative retreat-event convergence result.

## Scientific interpretation

The refinement experiment reveals two distinct facts:

1. RUNOFF event-time convergence is already positive at the two new finest levels.
2. HEAD cannot currently test the same convergence gate because a much earlier saturation-entry root trial fails at the finest dt.

The HEAD blocker occurs far before the dry-phase retreat event and is therefore outside the retreat-event estimator itself.

Do not relax the NLGLOB14N convergence threshold and do not infer that HEAD retreat timing fails to converge.

## Blocker attribution

The blocked finest HEAD case:

- material: O05;
- mode: TG;
- wet-entry route: HEAD;
- dt: `7.8125e-6 d`;
- terminal reason: `SATURATION_ROOT_TRIAL_OTHER_FAILED`;
- steps completed: 82;
- state finite: yes;
- physical mass valid: yes.

This points to fine-dt saturation-entry event localization robustness, not release-event physics.

## Consequence

Open a separately preregistered bounded successor:

`F-PE-NLGLOB14N1 — fine-dt saturation-entry root-trial failure attribution`.

That successor should diagnose why the existing saturation-root trial fails for the single finest HEAD case without changing:

- retreat-event definition;
- NLGLOB14N convergence gate;
- saturation root itself;
- timestep ladder;
- physical mass authority.

Once that blocker is removed or explained, rerun the unchanged NLGLOB14N convergence gate.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No event, release or numerical default changed.

`LEGACY_NUMERICS` remains production default.
