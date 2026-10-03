# F-PE-NLGLOB14R result — accepted first-retreat TG handoff persistence falsification

Date: 2026-09-29

Status:

`NLGLOB14R_MIXED_HANDOFF_PERSISTENCE`

Qualification authority:

- workflow run: `36589388847`;
- job: `109478292008`;
- conclusion: SUCCESS.

## Frozen question

After accepting exactly one qualified full-column TG interval at first retreat, does the immediately following ordinary interval remain under stable TG ownership or re-enter persistent saturated mode?

## Coverage

PASS.

All 12 six-level O05 fixtures:

- reach the qualified handoff;
- accept the first TG interval;
- preserve dry forcing and surface-flux ownership;
- remain finite and mass-clean through that accepted handoff;
- enter the frozen immediate-following-step test.

The accepted first TG interval succeeds in all 12 fixtures and leaves 13 saturated nodes.

## Immediate-following-step result

The second TG interval does not complete in any fixture.

Observed in all 12:

- saturated mode remains off;
- saturated-node count remains 13 at the observed failure state;
- no saturation-event re-entry is recorded;
- terminal reason is `ENDPOINT_SOLVE_FAILURE`;
- accepted physical mass prior to the failed follow-up remains clean.

Thus no fixture qualifies:

- `STABLE_TG_OWNERSHIP_AFTER_HANDOFF`;
- `IMMEDIATE_SATURATED_MODE_REENTRY`;
- `TG_HANDOFF_FIRST_INTERVAL_FAILURE`;
- `HANDOFF_STATE_OR_MASS_INCONSISTENT`.

All 12 fall into the preregistered otherwise/mixed surface through a uniform follow-up failure.

Frozen aggregate classification:

`NLGLOB14R_MIXED_HANDOFF_PERSISTENCE`.

## Physical admissibility

Across the accepted trajectory up to the failed follow-up attempt:

- max interval ledger about `2.68e-14 cm`;
- max cumulative ledger about `9.12e-14 cm`;
- no accepted-state or mass inconsistency appears.

## Scientific interpretation

First-retreat ownership can transfer to TG for one accepted interval.

That does not yet establish persistent TG ownership.

The next ordinary TG interval fails at the endpoint solver before the existing saturation-event machinery classifies re-entry. Therefore NLGLOB14R does not show mode chatter, and it also does not show stable TG continuation.

The unresolved mechanism is the uniform second-interval endpoint solve failure.

## Consequence

Do not introduce a release rule from NLGLOB14R.

Open a separately preregistered follow-up failure attribution that preserves:

- the accepted first TG handoff;
- the dry forcing;
- the same second interval;
- the same solver limits and tolerances;
- existing saturation/event semantics.

The first question is whether the second-interval endpoint failure is a retry-advised solver outcome, a hard solver failure, or a predictor/route failure hidden by the harness-level terminal label.

## Production boundary

Research only.

No production `src/**` change.

No numerical default or production temporal-mode ownership changed.

`LEGACY_NUMERICS` remains production default.
