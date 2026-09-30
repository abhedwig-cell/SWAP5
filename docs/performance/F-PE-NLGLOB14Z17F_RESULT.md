# F-PE-NLGLOB14Z17F result — two-recovery fine-RUNOFF continuation to 13:16 -> 14:16

Date: 2026-09-30

Status:

`QUALIFIED_Z17F_REPAIRED_FINE_RUNOFF_RETREAT_13_TO_14`

Qualification authority:

- workflow run: `36695555280`;
- job: `109822547419`;
- conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

## Frozen question

Can fine RUNOFF reach exact accepted retreat:

`13:16 -> 14:16`

while using exactly the two already-qualified local retry recoveries and no third repair?

## Result

PASS.

The trajectory reproduces both known nominal retries:

1. step `1,138,915` at 71.1821875 d;
2. step `5,568,677` at 348.0423125 d.

For both:

- rejected nominal candidate is not accepted;
- rollback is exact;
- both half-dt intervals are accepted;
- no half-step retry occurs;
- nominal dt resumes afterward.

No third retry occurs through 540.0 d.

## Physical event

Exact accepted transition:

`13:16 -> 14:16`

occurs at:

`514.6615625 d`.

Accepted pre/post saturated sets are exactly:

- pre: nodes 13:16;
- post: nodes 14:16.

No reverse transition, skipped node, noncontiguous tail or h/theta indicator inconsistency is observed.

## State and mass

- trajectory completes 540.0 d;
- final accepted tail: 14:16;
- state finite;
- max interval physical mass ledger about `2.36e-14 cm`;
- cumulative accepted ledger about `7.10e-11 cm`;
- rollback differences zero.

## Restored four-fixture event authority

Accepted control event evidence for `13:16 -> 14:16` now consists of:

- coarse HEAD, unmodified Z17: 514.664625 d;
- fine HEAD, repaired Z17C: 514.66475 d;
- coarse RUNOFF, repaired Z17C: 514.661375 d;
- fine RUNOFF, two-recovery Z17F: 514.6615625 d.

Thus four-fixture research authority is restored under the explicitly documented bounded local-retry research policy.

## Scientific interpretation

The second fine-RUNOFF retry is a separate local temporal-resolution event, not a physical-state failure.

Two distinct one-level local recoveries are sufficient to continue nominal progress all the way through the independently exposed physical retreat without a third repair.

## Qualified claim boundary

Qualified:

`QUALIFIED_Z17F_REPAIRED_FINE_RUNOFF_RETREAT_13_TO_14`.

Downstream implication:

four-fixture control authority is restored for `13:16 -> 14:16`.

Not qualified:

- production adaptive stepping;
- later retreats beyond 14:16;
- complete saturated-block disappearance;
- whole-column TG re-entry.

## Consequence

A separately preregistered split successor may now test:

`13:16 -> 14:16`

with state-derived ownership move:

`face 12/13 -> face 13/14`.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
