# F-PE-NLGLOB14W result — split ownership transition across second retreat

Date: 2026-09-29

Status:

`QUALIFIED_SPLIT_SECOND_RETREAT_OWNERSHIP_TRANSITION`

Qualification authority:

- workflow run: `36604840491`;
- job: `109531106449`;
- conclusion: SUCCESS.

The preceding run `36604723809` exercised the wrong inherited fixture constants (0.05 d and six dt levels) because of a harness substitution error. Commit `c2a9117da30a42fed3d9c53f17e830b1eb236ec0` repaired only the preregistered fixture constants to 0.12 d and four dt levels. No solver formulation, gate or hypothesis changed.

Canonical authority rechecked before result persistence:

`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

## Frozen question

Can the split accepted-state trajectory independently traverse the control-exposed second retreat and move ownership:

`face 3/4 -> face 4/5`

only when its own accepted saturated set changes:

`nodes 4:16 -> nodes 5:16`?

## Coverage

PASS.

All 8 HEAD/RUNOFF x four-dt fixtures classify:

`SPLIT_SECOND_RETREAT_TRANSITION_VALID`.

Aggregate classification:

`QUALIFIED_SPLIT_SECOND_RETREAT_OWNERSHIP_TRANSITION`.

Observed across the bank:

- accepted split intervals: 11,517;
- process failures: 0;
- rejected intervals: 0;
- interface transitions: 8, exactly one per fixture;
- chatter cases: 0;
- reverse 4/5 -> 3/4 cases: 0;
- noncontiguous saturated geometries: 0.

## Ownership transition

Every fixture begins the relevant phase with:

- saturated set nodes 4:16;
- upper TG ownership nodes 1:3;
- ownership face 3/4.

Every fixture independently reaches an accepted state with:

- saturated set nodes 5:16;
- upper TG ownership nodes 1:4;
- ownership face 4/5.

The split transition is not prescribed from control time.

It follows only after node 4 has left the split trajectory's own accepted physical saturated set.

## Event timing versus independent control

HEAD:

- dt 2.5e-4 d: split 0.10625 d, control 0.10625 d, difference 0;
- dt 1.25e-4 d: split 0.10625 d, control 0.106125 d, difference 1 dt;
- dt 6.25e-5 d: split 0.1060625 d, control 0.1060625 d, difference 0;
- dt 3.125e-5 d: split 0.10600 d, control 0.10596875 d, difference 1 dt.

RUNOFF:

- dt 2.5e-4 d: split 0.10625 d, control 0.10600 d, difference 1 dt;
- dt 1.25e-4 d: split 0.106125 d, control 0.106125 d, difference 0;
- dt 6.25e-5 d: split 0.10600 d, control 0.10600 d, difference 0;
- dt 3.125e-5 d: split 0.1059375 d, control 0.1059375 d, difference 0.

Thus the state-derived split transition occurs at the same accepted step as control in 5/8 cases and one timestep later in 3/8.

Event-time equality was diagnostic only and was not a qualification gate.

## Conservation and transaction behavior

All transition trajectories remain conservative and rollback-safe.

Observed maxima:

- absolute interval physical mass ledger: about `6.88e-10 cm`;
- node-equation residual: about `6.74e-11`;
- rollback difference: 0.

These remain inside the preregistered gates.

No second interface flux authority, fitted interface head or residual redistribution is used.

## Dynamic-top behavior

All accepted split intervals remain on the reconstructed dry unponded B110 `surface-flux` route.

The split solver does not replay the persistent-KLAG top-flux sequence.

The top boundary therefore remains state-driven within the frozen dry forcing contract.

## Control trajectory comparison

Matched split/control state differences remain finite and decrease with timestep refinement.

The maximum head discrepancy over the full 0.12 d trajectory is larger than in the shorter NLGLOB14U horizon, reaching about 0.058 cm in the coarsest RUNOFF case, but falls to about 0.006-0.007 cm at the finest retained level.

Theta differences similarly decrease with refinement.

This is supporting trajectory-consistency evidence. It is not a separate temporal-order qualification.

## Scientific interpretation

NLGLOB14W supplies the missing mechanistic evidence that NLGLOB14S, 14T and 14U could not provide.

Split temporal ownership is not merely mechanically decomposable or persistently stable. It can move its ownership edge across a genuine accepted physical lower-block retreat.

The transition requires no:

- whole-column TG release;
- saturation-count heuristic detached from state;
- h/theta fitted threshold;
- interface-head fit;
- independent upper/lower interface flux;
- residual redistribution;
- tolerance tuning.

The actual accepted physical state moves the interface.

## Qualified claim boundary

Qualified:

`QUALIFIED_SPLIT_SECOND_RETREAT_OWNERSHIP_TRANSITION`.

This establishes one real state-driven moving-interface transition under the O05 dry-reversal bank.

Not yet qualified:

- arbitrary repeated ownership transitions over many retreat events;
- disappearance of the remaining saturated block;
- whole-column TG re-entry after disappearance;
- production temporal ownership.

Those remain successor questions.

## Production boundary

Research only.

No production `src/**` change.

No production numerical default or temporal-ownership policy changed.

`LEGACY_NUMERICS` remains production default.
