# F-MIG431-LOW03-A qualification closeout

Final status: **CANONICAL_ADMITTED_CLOSED**.

Qualified exact postimage: `2634098e621dc6a7358ab20ea70f7dd196b3ba26`.

Persisted GitHub Actions authority:

- run: `36990238847`;
- conclusion: SUCCESS;
- artifact: `11219740959`, `F-MIG431-LOW03-A-qualification`.

## Qualified scope

Ordinary, non-groundwater-owned SWBOTB=3 with implicit `SwBotb3Impl=1`, Reference `SWKIMPL=0`, homogeneous bare/non-macropore profile, `SHAPE_3=1`, DATE3/HAQUIF or legacy sinus aquifer head, optional independent DATE4/QBOT4, and the already admitted LOW03-P0 typed mode-3 law.

The application preserves the B1.11 clock split:

- table Haq is sampled at the original proposal endpoint;
- sinus Haq uses proposal-start calendar phase;
- Haq is frozen across shortened retries belonging to that proposal;
- Q4 is sampled independently at each actual solve endpoint and is immutable only within that solve.

## Temporal prerequisite closure

The initial external full/two-half identity policy was falsified for implicit Cauchy application staging. LOW03-A did not weaken it.

DEP02 instead composes the already production-shaped Richards temporal-certificate/history route. The only new numerical operator semantics are the mode-3 bottom Robin stiffness in the existing defect operator:

`G = 1 / (0.5 dz / Kb + RIMLAY)`

with half-cell resistance, or `G = 1/RIMLAY` without it.

An independent local Thomas oracle qualifies this operator at O0 and O2. No production application accuracy budget is introduced by the provider or solver; qualification supplies its budget explicitly.

## Transaction and restart evidence

The qualification includes:

- real certificate-driven shortened progress;
- proposal history retained across retries;
- trial-local Q4 sampling;
- accepted private progress followed by outer rollback;
- deterministic replay after rollback;
- one external commit for a completed requested interval;
- accepted temporal-history export and restore through existing Restart v1;
- fresh-backend continuation;
- changed Haq/Q4 continuation after restart;
- missing required history fail-closed.

## Mass and ownership

The physical mode-3 solver result owns total `qbot = Cauchy + Q4`. Existing transaction accounting books that physical bottom flux exactly once. No separate Q4 ledger term was introduced. Hard whole-profile mass gates remain unchanged.

## Preservation

Run `36990238847` passes O0/O2 gates for LOW03-P0, LOW05-A against current canonical semantic authority, LOW01-A, prescribed-qbot application and the general production bootstrap. The historical LOW05-A solver-contract blob guard is explicitly superseded by current canonical authority; the semantic replay is green.

## Nonclaims

This closeout does not admit explicit `SwBotb3Impl=0`. It does not unpark SWBOTB=1. It does not admit SWBOTB=8. It does not add groundwater ownership, a MODFLOW datum conversion, a public C ABI or a new restart format.

Canonical admission: PR #977, normal merge `6f2b1b73a02d1f6492cc31cfea13964d3020854e` at 2026-10-02T09:41:32Z.
