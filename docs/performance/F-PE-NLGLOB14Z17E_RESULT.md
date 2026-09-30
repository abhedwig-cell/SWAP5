# F-PE-NLGLOB14Z17E result — second local retry recovery

Date: 2026-09-30

Status:

`QUALIFIED_Z17E_SECOND_LOCAL_RETRY_RECOVERY`

Qualification authority:

- workflow run: `36694858075`;
- job: `109820273150`;
- conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

## Frozen question

Can the fine-RUNOFF trajectory recover both known retry-advised intervals using exactly two separate one-level local recoveries:

`dt -> dt/2 + dt/2 -> dt`

without a third retry before 360.0 d?

## Result

PASS.

Observed nominal retry windows:

1. step `1,138,915`, time 71.1821875 d;
2. step `5,568,677`, time 348.0423125 d.

For both retry windows:

- nominal retry reproduced;
- rejected nominal candidate not accepted;
- rollback exact;
- half 1 accepted;
- half 2 accepted;
- no half-step retry;
- one nominal time window recovered exactly;
- nominal dt restored afterward.

Recovery count:

`2`.

Third retry count through 360.0 d:

`0`.

The trajectory completes 360.0 d with terminal reason:

`COMPLETE_SAME_ROUTE`.

## State and mass

- final state finite;
- accepted geometry valid;
- max interval physical mass ledger about `2.36e-14 cm`;
- cumulative accepted ledger about `1.83e-11 cm`;
- rollback differences zero.

## Scientific interpretation

The second long-horizon fine-RUNOFF retry is another local nonlinear temporal-resolution event.

The existing transaction semantics remain sufficient when applied independently at two distinct accepted origins.

No recursive subdivision, tolerance tuning, forcing change or physical-threshold change is required.

## Qualified claim boundary

Qualified:

`QUALIFIED_Z17E_SECOND_LOCAL_RETRY_RECOVERY`.

Not yet qualified:

- continuation to accepted `13:16 -> 14:16` under the two-recovery policy;
- four-fixture control authority for that event;
- split ownership beyond 13:16;
- production adaptive stepping;
- disappearance;
- whole-column TG re-entry.

## Consequence

A separately preregistered continuation may run fine RUNOFF to the target event with exactly the two already-qualified local recoveries permitted and no third repair.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
