# F-PE-TIMEARCH13 result — look-ahead boundary-risk AUTO_REFERENCE controller

Date: 2026-09-28

Status: `CLOSED_LOOKAHEAD_BOUNDARY_RISK_NOT_SELECTIVE`

Canonical base:

`integration/f-ci-canonical@3faa901ff99880d3c1b3f8747646e471e18644e4`

Evidence:

- Actions run: `36431160218`;
- discovery job: `108957392543`;
- conclusion: SUCCESS.

## Candidate family

Base proposal used the previously promising normalized accepted-state signal:

`r_h = max_i(|dh_i|/max(10 cm,|h_i|))`

with target `R=0.40`, no normal operating DTMAX and internal retry floor only.

Four cheap boundary-risk variants were tested:

- ORIGIN_HOLD;
- ORIGIN_HALF;
- LINEAR_HOLD;
- LINEAR_HALF.

The LINEAR variants extrapolated top head using accepted history before calling the existing corrected dynamic-top boundary provider.

## Result

No candidate advanced.

### ORIGIN_HOLD
- P-C1 pass: 11/16;
- median work reduction on passing cases: about 34.5%;
- wet/ponding preservation: FAIL;
- median risk events: 0.

### ORIGIN_HALF
- P-C1 pass: 11/16;
- median work reduction: about 34.5%;
- wet/ponding preservation: FAIL;
- median risk events: 0.

### LINEAR_HOLD
- P-C1 pass: 12/16;
- median work reduction: about 34.4%;
- wet/ponding preservation: FAIL;
- median risk events: 0.

### LINEAR_HALF
- P-C1 pass: 11/16;
- median work reduction: about 34.5%;
- wet/ponding preservation: FAIL;
- median risk events: 0.

## Interpretation

The state-change proposal continues to expose substantial performance headroom.

The pre-solve boundary-risk predictor is not selective enough because most unsafe transitions are not classified risky at the accepted origin or simple linear look-ahead state.

This is consistent with DYNERR01, where the critical failure mechanism was a boundary path transition hidden by endpoint-local linearization.

## Decision

Do not advance origin-frozen or linear-look-ahead boundary-risk control.

The next valid architecture should detect boundary-mode transitions from the actual candidate trial and use transaction rollback/refinement only when a transition is observed.

No production controller is enabled.
