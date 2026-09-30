# F-PE-NLGLOB14Z17C result — repaired continuation to 13:16 -> 14:16

Date: 2026-09-30

Status:

`BLOCKED_NLGLOB14Z17C_BY_RECURRENT_FINE_RUNOFF_RETRY`

with preserved accepted event evidence in 2/3 repaired fixtures plus the original unmodified coarse-HEAD Z17 event.

Qualification authority:

- workflow run: `36692861086`;
- HEAD fine job: `109813862730`;
- RUNOFF coarse job: `109813862849`;
- RUNOFF fine job: `109813862853`;
- workflow conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@656ddea918c58267a08c2b626d498c998daccc60`

The intervening canonical change relative to earlier NLGLOB work only adds typed mass-residual publication for bottom mode 7. This line uses bottom mode 2, so the exercised solver/retry path is unchanged.

## Frozen question

Can the three repaired Z17 controls continue to and through exact accepted:

`13:16 -> 14:16`

using exactly one already-qualified local recovery per fixture and no second repair?

## HEAD fine

PASS.

- nominal retry reproduced at step 2,649,048;
- exact rollback;
- both half steps accepted;
- no recurrent retry through 540.0 d;
- complete 540.0 d trajectory;
- exact accepted event at 514.66475 d;
- final accepted tail 14:16;
- finite, contiguous and mass-clean.

Fixture classification:

`QUALIFIED_Z17C_REPAIRED_RETREAT_13_TO_14`.

## RUNOFF coarse

PASS.

- nominal retry reproduced at step 1,659,714;
- exact rollback;
- both half steps accepted;
- no recurrent retry through 540.0 d;
- complete 540.0 d trajectory;
- exact accepted event at 514.661375 d;
- final accepted tail 14:16;
- finite, contiguous and mass-clean.

Fixture classification:

`QUALIFIED_Z17C_REPAIRED_RETREAT_13_TO_14`.

## RUNOFF fine

Blocked by a second retry before the target event.

- first known retry at step 1,138,915 is reproduced and locally recovered exactly;
- nominal dt resumes;
- a second endpoint-solve retry occurs at 348.0423125 d;
- accepted tail at the second retry remains 13:16;
- target 13:16 -> 14:16 is not yet reached;
- accepted state remains finite;
- geometry remains valid;
- mass remains clean;
- no reverse or skipped node is observed.

Fixture classification:

`Z17C_RECURRENT_RETRY_BEFORE_EVENT`.

## Physical mass

Observed maxima remain roundoff-scale in the control trajectories:

- interval ledger up to about `2.36e-14 cm`;
- cumulative accepted ledger up to about `7.45e-11 cm` in the completed repaired trajectories.

No mass correction or redistribution is used.

## Scientific interpretation

The first local-retry recovery policy remains sufficient for HEAD fine and RUNOFF coarse through the target event.

Fine RUNOFF exposes a genuinely new numerical boundary: a second local retry-advised interval at 348.0423125 d, well after the first repaired interval and before the target retreat.

This is not evidence against the physical event. It is evidence that the one-repair-only Z17C policy is insufficient for this one long-horizon trajectory.

## Preserved event authority

Accepted event evidence for `13:16 -> 14:16` now exists in:

- original coarse HEAD Z17;
- repaired HEAD fine Z17C;
- repaired RUNOFF coarse Z17C.

The fourth member, fine RUNOFF, remains missing.

Therefore four-fixture control authority is not yet restored and downstream split ownership is not yet authorized.

## Direct successor

Open a separately preregistered fine-RUNOFF second-retry attribution workunit around 348.0423125 d.

It must establish:

- exact terminal step/time;
- retry-advised status;
- accepted tail at second retry origin;
- exact rollback;
- state finiteness;
- physical mass;
- whether one additional bounded `dt/2 + dt/2` recovery is locally admissible.

Do not change tolerances, forcing, nominal dt or physical thresholds.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
