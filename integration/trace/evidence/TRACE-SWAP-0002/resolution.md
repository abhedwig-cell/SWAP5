# TRACE-SWAP-0002 resolution

Date: 2026-09-19
Outcome: `CONFIRMED_AND_CLOSED`
Disposition: `DOCUMENTATION_CORRECTED`
Regression counterfactual: `REGRESSION_NOT_APPLICABLE`

## Confirmed discrepancy

The current canonical repository contained the admitted restricted Snow scientific reference, but `integration/f-doc/F-DOC23_STATUS.json` still represented a pre-admission state:

- `phase=VERIFY`;
- `PASS_READY_FOR_ADMISSION`;
- the next action still instructed admission of PR #170.

PR #170 had already merged.

## Chronology

The F-DOC23 sequence is reconstructable:

1. content head `83513160269a3a7c8989fd50071ecc2b16268f00` passed Documentation run `35184833980`;
2. verify checkpoint `fc8c2f9f42573d25101bf36f11d7d0bd3b4c7dd0` passed Documentation run `35184887753`;
3. PR #170 merged that checkpoint as canonical merge `2a6eb532c922add0afbc15fdf7f3bee11ed8ea33`;
4. the F-DOC23 branch then advanced by exactly one status-only commit to `4cb2425147624a33cc01e767b2f5eaa0ae062712`;
5. that closeout status records `phase=CLOSE`, `ADMITTED_AND_CLOSED`, the admitted canonical merge and no further F-DOC23 action;
6. the closeout status was not propagated back to canonical.

No immutable authoring-freeze contract assigns the canonical VERIFY status a permanent provenance role.

## Scientific consequence

The demonstrated consequence is interpretative.

A reviewer using canonical could conclude that the WOFOST/Snow documentation workunit was still awaiting admission after admission had already occurred.

The underlying Snow scientific contract was not in conflict. The reviewer page, frozen Snow process blob `54702d71b4c84dce2842813549bd14c57301a383`, F-VQ16 authority and F-PM02 current-canonical preservation agree on the bounded one-call-daily formulation and its claim ceiling.

No Snow state, melt law, sublimation routing, mass classification, transaction behaviour, runtime result or scientific tolerance changed.

## Regression counterfactual

`REGRESSION_NOT_APPLICABLE`.

The pre-existing Documentation workflow ran on the verify checkpoint before PR merge. It could not detect a later failure to propagate a post-merge status-only closeout object.

No pre-existing post-merge status-synchronization oracle was identified.

## Repair

The repair copies the already-existing authoritative F-DOC23 post-merge closeout status exactly onto the current canonical lineage.

No reviewer content, production source, reference source, tests, Snow physics, runtime semantics or tolerances are changed.

Repair postimage:

`bbdb3b8e56d13a16a2a6fd7f22d4681e2ad8286f`

Qualification:

- TRACE research integrity run `35439141518`: success;
- F-GC42 live whole-window preservation run `35439141610`: success.

## TRACE significance

This is the second confirmed prospective SWAP TRACE discrepancy and the second observed SWAP case of post-merge closeout status not reaching canonical.

That repeated mechanism is noteworthy but is not yet a repository-wide rate or general software claim.
