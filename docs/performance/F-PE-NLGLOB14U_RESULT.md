# F-PE-NLGLOB14U result — accepted-state split evolution with moving-interface ownership rule

Date: 2026-09-29

Status:

`QUALIFIED_MOVING_INTERFACE_ACCEPTED_STATE_EVOLUTION_RESEARCH`

Qualification authority:

- workflow run: `36603718654`;
- job: `109527274205`;
- conclusion: SUCCESS.

Canonical authority rechecked before result persistence:

`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

## Frozen question

Can the qualified NLGLOB14T split endpoint be accepted repeatedly into a private research state while:

- ownership is recomputed from each accepted physical saturated set;
- one shared interface exchange remains authoritative;
- mass and rollback semantics remain conservative;
- no threshold, fitted interface head or residual redistribution is introduced?

## Coverage

PASS.

All 12 HEAD/RUNOFF x six-dt fixtures classify:

`MOVING_INTERFACE_ACCEPTED_STATE_EVOLUTION`.

Aggregate preregistered classification:

`QUALIFIED_MOVING_INTERFACE_ACCEPTED_STATE_EVOLUTION_RESEARCH`.

Across the bank:

- total accepted research split intervals: 4521;
- process failures: 0;
- chatter events: 0;
- noncontiguous saturated sets: 0;
- upper-domain saturation events: 0;
- rejected-state rollback differences: 0.

## Transaction and mass result

The accepted split sequence remains transactionally clean.

Observed maxima:

- absolute single-interval physical mass ledger: about `6.88e-10 cm`;
- absolute cumulative split-sequence ledger: about `1.80e-9 cm`;
- node residual: about `6.74e-11`;
- rollback difference: 0.

All remain inside the frozen gates.

The private research accepted state advances only after a candidate passes its interval gates.

## Interface behavior

No fixture changes ownership face within the bounded 0.05 d horizon.

Observed:

- initial saturated-block top: node 4;
- final saturated-block top: node 4;
- interface transitions: 0/4521 accepted intervals;
- saturated-block disappearance: 0/12 fixtures;
- chatter: 0.

This does not falsify the moving-interface rule.

The persistent-KLAG control authority from NLGLOB14L independently shows that after the first 14 -> 13 retreat the physical saturated set also remains nodes 4:16 through 0.05 d. The bounded NLGLOB14U horizon therefore contains no second physical retreat event against which a 3/4 -> 4/5 ownership move could be exercised.

The correct interpretation is consequently narrower than the aggregate label may suggest:

- accepted split ownership is persistent and stable over many intervals;
- recomputing ownership from accepted state does not introduce chatter or inconsistency;
- actual interface migration beyond the first-retreat 3/4 face is **not yet observed or qualified**.

## Control comparison

Matched-time differences from persistent KLAG remain finite.

At the coarser horizons that reach 0.05 d, maximum head differences are of order `1e-2 cm` or smaller and decrease with dt refinement; theta differences likewise decrease with dt.

This supports bounded trajectory consistency but is not a separate formal temporal-convergence qualification.

## Scientific interpretation

NLGLOB14U extends NLGLOB14T from one shadow interval to thousands of accepted research intervals without uncovering:

- interface-authority conflicts;
- mass leakage;
- transaction leakage;
- upper-domain saturation re-entry;
- noncontiguous lower saturated sets;
- chatter.

The lower block remains physically saturated over the observed period, so the ownership face correctly remains 3/4.

The next unresolved mechanism is no longer persistence of split ownership. It is **exposure and qualification of the next genuine lower-block retreat event**.

## Consequence

Open a separately preregistered extended-horizon successor that first establishes when the persistent-KLAG control moves from saturated block 4:16 to 5:16, and then tests whether the split accepted-state trajectory performs the same ownership-face move without threshold fitting or chatter.

Do not infer interface mobility merely from NLGLOB14U's positive aggregate class.

## Production boundary

Research only.

No production `src/**` change.

No production temporal-ownership policy or numerical default changed.

`LEGACY_NUMERICS` remains production default.
