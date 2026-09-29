# F-PE-NLGLOB14W result — split accepted-state second-retreat ownership transition

Date: 2026-09-29

Status:

`QUALIFIED_SPLIT_SECOND_RETREAT_OWNERSHIP_TRANSITION_RESEARCH`

Qualification authority:

- workflow run: `36605281077`;
- job: `109532610935`;
- conclusion: SUCCESS.

Canonical authority rechecked before result persistence:

`integration/f-ci-canonical@60a58bef6c2922727817728314676d493223881c`

Research postimage used by the qualifying run:

`research/f-pe-nlglob14w-split-second-retreat-transition@2898e256b68ea28d0d85b9803b2a02677fccfe42`

## Frozen question

Can the split accepted-state trajectory, without being given the independently observed control event time, carry the accepted saturated set from nodes 4:16 to nodes 5:16 and consequently move its single temporal-ownership interface from face 3/4 to face 4/5?

## Coverage

PASS.

All 8 preregistered O05 fixtures:

- HEAD and RUNOFF;
- dt = 2.5e-4, 1.25e-4, 6.25e-5 and 3.125e-5 d;
- horizon = 0.12 d;

classify:

`SPLIT_SECOND_RETREAT_OWNERSHIP_TRANSITION`.

Aggregate classification:

`QUALIFIED_SPLIT_SECOND_RETREAT_OWNERSHIP_TRANSITION_RESEARCH`.

Across the bank:

- 11,517 accepted split research intervals;
- 8/8 state-derived second-retreat events;
- 8/8 interface transitions;
- 0 chatter events;
- 0 noncontiguous saturated sets;
- 0 process failures;
- exact rejected-state rollback difference = 0.

## Ownership transition

Every fixture begins the post-first-retreat split phase with:

- saturated lower block = nodes 4:16;
- upper TG domain = nodes 1:3;
- ownership interface = face 3/4.

Every fixture later reaches an accepted physical state with:

- saturated lower block = nodes 5:16;
- node 4 unsaturated;
- ownership interface for the following interval = face 4/5.

No event time, head threshold, theta threshold, saturated-count release heuristic or hysteresis was used to trigger the move.

The transition is derived only from the accepted split physical state.

No reverse 5:16 -> 4:16 ownership move occurs through 0.12 d.

## Event timing against independent control

The split event was identified independently and compared with NLGLOB14V only after detection.

HEAD:

- dt 2.5e-4 d: split 0.10625 d, control 0.10625 d;
- dt 1.25e-4 d: split 0.10625 d, control 0.106125 d;
- dt 6.25e-5 d: split 0.1060625 d, control 0.1060625 d;
- dt 3.125e-5 d: split 0.10600 d, control 0.10596875 d.

RUNOFF:

- dt 2.5e-4 d: split 0.10625 d, control 0.10600 d;
- dt 1.25e-4 d: split 0.106125 d, control 0.106125 d;
- dt 6.25e-5 d: split 0.10600 d, control 0.10600 d;
- dt 3.125e-5 d: split 0.1059375 d, control 0.1059375 d.

Thus the split transition occurs on the same accepted time level as control in five fixtures and one dt later in the remaining three.

This workunit did not preregister a separate event-time convergence criterion, so this comparison is diagnostic support rather than a broader temporal-convergence qualification.

## Transaction and mass result

All preregistered transaction and conservation gates pass.

Observed maxima:

- absolute single-interval physical mass ledger: about `6.88e-10 cm`;
- absolute cumulative split-sequence ledger: about `1.05e-8 cm`;
- nonlinear residual: about `6.74e-11`;
- rollback difference: 0.

All are inside the frozen gates:

- interval and cumulative mass <= `5e-8 cm`;
- residual <= `1e-10`;
- rollback <= `1e-15`.

The shared moving-interface exchange remains single-valued; no residual redistribution or independent interface-flux fitting is used.

## Control trajectory comparison

Matched-time split/control differences remain finite through 0.12 d.

The largest recorded head and theta differences remain small relative to the profile scale and decrease with dt refinement in the observed sequence.

NLGLOB14W does not promote those differences into an identity or general accuracy claim. The qualified claim is the physical ownership transition and the preserved transaction/mass contract.

## Harness-history boundary

Runs `36604544998`, `36604770392` and `36605173924` are excluded from scientific evidence.

They failed or were invalid before a valid NLGLOB14W result exposure because of:

- generated Python newline syntax;
- stale NLGLOB14U bank/horizon constants;
- missing transition-time instrumentation.

These were harness/configuration defects. None changed the preregistered scientific hypothesis or numerical formulation.

The qualification authority is only run `36605281077` against the repaired preregistered postimage.

## Scientific interpretation

The moving-interface split direction now passes a stronger test than mechanical decomposition or persistence alone.

The split research trajectory can:

1. evolve for many accepted finite intervals;
2. preserve one interface-exchange authority;
3. reproduce the next genuine lower saturated-block retreat;
4. move ownership from face 3/4 to 4/5 from accepted physical state alone;
5. continue after that transition without chatter or transaction leakage.

This directly addresses the mechanism that whole-column TG release could not represent.

## Consequence

The next scientifically meaningful successor is no longer another first-retreat or single-face test.

It should test repeated moving-interface evolution over a longer independently justified horizon, including:

- additional retreats 5:16 -> 6:16 and beyond if physically exposed;
- repeated interface changes without chatter;
- eventual disappearance of the saturated lower block if observed;
- only then, eligibility for return to whole-column TG;
- broader materials and forcing before any production admission.

No production implementation is authorized by NLGLOB14W alone.

## Production boundary

Research only.

No production `src/**` change.

No production temporal-ownership policy or numerical default changed.

`LEGACY_NUMERICS` remains production default.
