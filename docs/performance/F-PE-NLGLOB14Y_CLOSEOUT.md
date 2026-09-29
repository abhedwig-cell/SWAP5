# F-PE-NLGLOB14Y closeout — multi-retreat split ownership sequence

Date: 2026-09-29

Final status:

`QUALIFIED_SPLIT_MULTI_RETREAT_OWNERSHIP_SEQUENCE`

Qualification authority:

- run `36606241010`;
- job `109535867357`;
- conclusion: SUCCESS.

## Closure

NLGLOB14Y closes positively.

Across 93,117 accepted research intervals, all 8 fixtures independently follow the accepted saturated-tail sequence:

`4:16 -> 5:16 -> 6:16 -> 7:16`.

Temporal ownership follows exactly:

`3/4 -> 4/5 -> 5/6 -> 6/7`.

No control event time is imposed on the split trajectory.

## Evidence

- 8/8 fixtures qualify;
- 0 process failures;
- 0 rejected intervals;
- 24 ownership transitions;
- 0 chatter;
- 0 reverse transitions;
- 0 skipped interface nodes;
- 0 noncontiguous accepted saturated states;
- max interval physical mass ledger about `9.95e-10 cm`;
- max node residual about `9.95e-11`;
- rollback difference 0.

Third- and fourth-retreat split times remain within at most two fixed timesteps of the independent persistent-KLAG control.

## Mechanistic conclusion

The split/moving-interface route is now qualified beyond one isolated retreat.

It supports repeated accepted physical retreat with a single interface authority and state-derived ownership, while preserving mass and transaction semantics.

The old whole-column first-retreat release route remains falsified and is not needed to obtain stable post-retreat evolution.

## Remaining scientific boundary

The lower saturated block is still present at the maximum independently exposed 0.80 d horizon:

`nodes 7:16`.

Therefore the next unresolved scientific questions are:

1. whether the control ultimately reaches complete disappearance under unchanged forcing;
2. whether split ownership follows the remaining retreats through disappearance;
3. only then, whether whole-column TG re-entry from an empty accepted saturated set is stable and conservative.

No whole-column TG re-entry study is authorized before those conditions are met.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14Y

BASELINE: `f8fc0ce1fdd89e6a47e52cedd983d9ff26397a3e`

BRANCH: `research/f-pe-nlglob14y-multi-retreat-split`

QUALIFICATION RUN: `36606241010`

STATUS: closed positive research qualification

QUALIFICATION STATUS: `QUALIFIED_SPLIT_MULTI_RETREAT_OWNERSHIP_SEQUENCE`

NEXT SAFE STEP: independently expose later retreat/disappearance in the control before extending split ownership or testing whole-column TG re-entry.

## Production boundary

No production source or default policy change.

`LEGACY_NUMERICS` remains production default.
