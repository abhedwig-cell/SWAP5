# F-PE-NLGLOB14Z12C result — repaired fine-RUNOFF continuation to 11:16 -> 12:16

Date: 2026-09-30

Status:

`QUALIFIED_REPAIRED_FINE_RUNOFF_RETREAT_11_TO_12`

Qualification authority:

- workflow run: `36676890632`;
- job: `109763075451`;
- conclusion: SUCCESS.

Canonical authority:

`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Frozen question

Can the fine-RUNOFF trajectory, repaired only by the Z12B-qualified one-level local subdivision at its first retry-advised interval, continue to the exact accepted physical retreat:

`11:16 -> 12:16`

and complete 140.0 d without a recurrent retry?

## Result

PASS.

The trajectory:

- reproduces exactly one nominal retry at step 1138915;
- uses exact rollback;
- accepts both half-dt recovery intervals;
- restores nominal dt;
- encounters no recurrent retry through 140.0 d;
- completes the full 140.0 d horizon.

Aggregate classification:

`QUALIFIED_REPAIRED_FINE_RUNOFF_RETREAT_11_TO_12`.

## Physical event

Exact accepted transition:

`11:16 -> 12:16`

occurs at:

`123.5846875 d`.

Accepted pre/post saturated sets are exactly:

- pre: nodes 11:16;
- post: nodes 12:16.

No reverse transition, skipped node, noncontiguous state or h/theta indicator inconsistency occurs.

## Transaction and mass

- rollback: exact;
- half-step recovery: valid;
- recurrent retries: 0;
- max interval physical mass ledger: about `2.36e-14 cm`;
- cumulative accepted ledger: about `2.20e-12 cm`;
- final state finite.

Final accepted saturated set at 140 d is nodes 12:16.

## Scientific interpretation

The missing fourth Z12 control event trajectory is recovered without changing:

- forcing;
- nominal timestep;
- solver tolerances;
- physical thresholds;
- accepted-state event definition.

The only intervention is the previously qualified transaction-safe local temporal subdivision at one retry-advised interval.

Combined with the three preserved unmodified Z12 controls, this restores four-fixture research authority for the physical retreat:

`11:16 -> 12:16`.

## Qualified claim boundary

Qualified:

`QUALIFIED_REPAIRED_FINE_RUNOFF_RETREAT_11_TO_12`.

Downstream implication:

the `11:16 -> 12:16` control event may now support a separately preregistered split ownership test under the explicitly documented bounded-retry research policy.

Not qualified:

- production adaptive stepping;
- later retreats beyond 12:16;
- complete saturated-block disappearance;
- whole-column TG re-entry.

## Consequence

The next safe workunit is split ownership through:

`11:16 -> 12:16`

with state-derived ownership move:

`face 10/11 -> face 11/12`.

## Production boundary

Research only.

No production `src/**` change.

`LEGACY_NUMERICS` remains production default.
