# F-PE-NLGLOB14N closeout — refined first-retreat event-time convergence

Date: 2026-09-29

Final status:

`BLOCKED_NLGLOB14N_REFINED_RETREAT_CONVERGENCE`

Canonical authority rechecked before closeout:

`integration/f-ci-canonical@a6e4579a98b127eb95f271e855aafe9d1e394c80`

The intervening canonical delta is outside the NLGLOB14N temporal/event dependency surface.

Qualification authority:

- frozen qualification run `36569762769`;
- diagnostic-only rerun `36570032078`;
- latest job `109411452773`;
- conclusion: SUCCESS.

## Closure

NLGLOB14N cannot complete the frozen six-level convergence test because the finest HEAD case terminates before the retreat phase.

The blocked case is:

- O05 / TG / HEAD;
- dt = `7.8125e-6 d`;
- terminal reason = `SATURATION_ROOT_TRIAL_OTHER_FAILED`;
- stop step = 82;
- state finite;
- mass clean.

RUNOFF passes the refined convergence gate.

HEAD remains unclassified on retreat-time convergence because its finest fixture lacks coverage.

## Scientific conclusion

The remaining blocker is no longer the retreat-event definition or estimator.

It is fine-dt saturation-entry root-trial robustness upstream of the retreat event.

Do not widen the retreat convergence gate and do not reinterpret the missing HEAD result as a negative convergence result.

## Direct successor

Open:

`F-PE-NLGLOB14N1 — fine-dt saturation-entry root-trial failure attribution`.

The successor must remain observational first and isolate the exact root-trial failure path for the one blocked finest HEAD fixture.

Only after the blocker is resolved or safely classified may the unchanged NLGLOB14N retreat-time convergence gate be rerun.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14N

BASELINE: `a0295af615d04ec9a1b7653c92bef829bd6159ce`

CANONICAL RECONCILED THROUGH: `a6e4579a98b127eb95f271e855aafe9d1e394c80`

BRANCH: `research/f-pe-nlglob14n-refined-retreat-convergence-r2`

STATUS: blocked on upstream fine-dt saturation-entry root trial

TEST STATUS: focused six-level run PASS as harness execution

QUALIFICATION STATUS: `BLOCKED_NLGLOB14N_REFINED_RETREAT_CONVERGENCE`

NEXT SAFE STEP: preregister NLGLOB14N1 root-trial failure attribution

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
