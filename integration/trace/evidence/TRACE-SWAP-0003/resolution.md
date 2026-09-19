# TRACE-SWAP-0003 resolution

Date: 2026-09-19
Outcome: `CONFIRMED_AND_CLOSED`
Disposition: `DOCUMENTATION_CORRECTED`
Regression counterfactual: `REGRESSION_NOT_APPLICABLE`

## Confirmed discrepancy

Current canonical contained the admitted soil-hydraulic parameter-provenance reference, but `integration/f-doc/F-DOC33_STATUS.json` still represented a pre-admission state:

- `phase=VERIFY`;
- exact-head rerun `PENDING`;
- a future canonical recheck/merge action.

PR #200 had already merged.

## Chronology

1. F-DOC33 content head `d5672c166ce920387988047b516bd86f290cd38e` passed Documentation run `35282362847`.
2. Exact admission head `eb5dc693b98c9bf7025c1fd478eb3ac679bedd52` passed Documentation run `35282447627`.
3. PR #200 merged as canonical commit `d0a41c39d7ff95db99bcf8360ac9b474fdf164d7`.
4. The owner branch then advanced to `9f133284cd3bfe43a8be7e686988209c195d516c`.
5. The only changed path after the exact admission head was `integration/f-doc/F-DOC33_STATUS.json`.
6. That final status records `CLOSE`, `DOCUMENTATION_ADMITTED_AND_CLOSED` and `NONE_FOR_F-DOC33`.
7. The final closeout status was not propagated to canonical.

No immutable authoring-freeze contract makes the stale canonical status a deliberate current authority.

## Scientific consequence

The demonstrated consequence is interpretative.

The bounded provenance claims themselves remain consistent. F-DOC33 distinguishes exact internal aliases, model-dependent activation rules, model-specific supplemental evidence and still-unresolved original parser keyword/unit cells. It does not silently infer missing user-facing semantics.

No constitutive equation, parser behaviour, input value or numerical result is shown to be wrong.

## Regression counterfactual

`REGRESSION_NOT_APPLICABLE`.

The exact-head Documentation workflow ran before PR merge and correctly qualified that pre-admission head. The discrepancy arose later because the post-merge status-only closeout was not propagated to canonical.

No pre-existing post-merge status-synchronization oracle was identified.

## Repair

The exact existing F-DOC33 closeout status was propagated to the current canonical lineage.

Repair postimage:

`7910d1410e4639766304801143505e0ffd0d3926`

Qualification:

- TRACE research integrity run `35439595539`: success;
- F-GC42 live whole-window preservation run `35439595565`: success.

No reviewer provenance content, production source, reference source, tests, physics or numerical semantics changed.

## TRACE significance

SWAP-0003 is the third prospectively confirmed SWAP case with the same observed mechanism: a post-merge closeout status remained on the work branch while canonical retained the preceding pre-admission state.

This repeated observation supports treating post-merge authority propagation as a concrete governance failure mechanism in the observed TRACE sample. It does not establish its repository-wide frequency.
