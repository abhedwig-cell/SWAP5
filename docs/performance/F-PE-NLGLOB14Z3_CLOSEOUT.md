# F-PE-NLGLOB14Z3 closeout — repaired finest-dt continuation

Date: 2026-09-29

Final status:

`QUALIFIED_REPAIRED_FINEST_LATE_RETREAT_TRAJECTORY`

Qualification authority:

- run `36614000382`;
- job `109562257039`;
- conclusion: SUCCESS.

## Closure

NLGLOB14Z3 closes positively.

Both finest-dt O05 trajectories complete the full 2.80 d horizon after exactly one transaction-safe local retry recovery.

The bounded repair is:

`dt -> dt/2 + dt/2 -> dt`.

It occurs once per route and is not repeated again before 2.80 d.

## Physical event

Both repaired trajectories reach the accepted physical late retreat:

`7:16 -> 8:16`.

Event times:

- HEAD: 2.442890625 d;
- RUNOFF: 2.439703125 d.

The accepted saturated geometry remains contiguous and monotone.

## Transaction and mass

- rollback differences: zero;
- half-step retry: none;
- recursive subdivision: none;
- max interval mass ledger: about `2.65e-14 cm`;
- max cumulative mass ledger: about `2.04e-13 cm`.

## Recovered refinement implication

The original NLGLOB14Z1 frozen two-finest-level gate can now be evaluated using:

HEAD:
- dt 3.125e-5 d: 2.442875 d;
- dt 1.5625e-5 d repaired: 2.442890625 d;
- difference: 1.5625e-5 d;
- frozen threshold: 3.125e-5 d.

RUNOFF:
- dt 3.125e-5 d: 2.43971875 d;
- dt 1.5625e-5 d repaired: 2.439703125 d;
- difference: 1.5625e-5 d;
- frozen threshold: 3.125e-5 d.

Both repaired finest estimates also lie inside the preceding coarser accepted-event brackets.

Therefore the previously blocked late-retreat refinement gate is now positively recoverable under the explicitly qualified bounded retry policy.

## Direct successor

The next safe work should no longer focus on the 7:16 -> 8:16 event.

The remaining physical boundary is later retreat/disappearance of the saturated tail.

Future control work should:

1. preserve the qualified local-retry recovery semantics where needed;
2. expose later accepted retreats beyond 8:16;
3. seek complete disappearance without extrapolation;
4. only after split ownership also reaches an empty saturated set, test whole-column TG re-entry.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14Z3

BRANCH: `research/f-pe-nlglob14z3-repaired-late-retreat`

QUALIFICATION RUN: `36614000382`

STATUS: closed positive research qualification

QUALIFICATION STATUS: `QUALIFIED_REPAIRED_FINEST_LATE_RETREAT_TRAJECTORY`

DOWNSTREAM REQUALIFICATION: late `7:16 -> 8:16` event-time refinement gate passes under the qualified bounded retry policy.

NEXT SAFE STEP: later-retreat/disappearance control exposure with bounded retry semantics preserved.

## Production boundary

No production source or default policy change.

`LEGACY_NUMERICS` remains production default.
