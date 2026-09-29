# F-PE-NLGLOB14R2 closeout — post-handoff transaction retry recovery

Date: 2026-09-29

Final status:

`NLGLOB14R2_SINGLE_RETRY_INSUFFICIENT`

Qualification authority:

- run `36593061051`;
- job `109490856854`;
- conclusion: SUCCESS.

Diagnostic amendment:

- first exposed run `36592793921`;
- phase-identity bug documented in `F-PE-NLGLOB14R2_DIAGNOSTIC_AMENDMENT.md`;
- no frozen numerical rule or classification threshold changed.

## Closure

All 12 fixtures reproduce the same sequence:

1. nominal second TG interval requests retry;
2. accepted origin is restored exactly;
3. retry scale 0.5 is applied;
4. the first half-dt retry again requests retry;
5. no half-step endpoint is accepted.

No hard solver failure, route inconsistency, saturation-mode re-entry, accepted-state leakage or mass inconsistency is observed.

## Scientific conclusion

One application of the qualified retry scale is insufficient immediately after the first-retreat TG handoff.

This does not invalidate the handoff or the transaction retry mechanism. It establishes that the required accepted-progress scale lies below `0.5 * dt_nominal` for every frozen fixture.

The existing transaction contract already defines bounded repeated retry:

- retry scale = 0.5;
- max retries = 8.

The next question is therefore retry depth, not retry-scale design.

## Direct successor

Open:

`F-PE-NLGLOB14R3 — bounded recursive post-handoff retry-depth attribution`.

At the exact second-interval origin:

1. reproduce the nominal retry-advised attempt;
2. restore exactly;
3. repeatedly apply the existing 0.5 retry factor;
4. stop at the first accepted internal progress interval or after 8 retries;
5. do not yet require completion of the full original nominal window;
6. record retry depth, accepted dt, temporal owner, saturation state and physical mass.

Existing saturation-event semantics and NLGLOB14N3 root retry handling remain active.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14R2

BRANCH: `research/f-pe-nlglob14r2-transaction-retry-recovery`

STATUS: closed negative single-retry qualification

TEST STATUS: 12-case retry recovery PASS

QUALIFICATION STATUS: `NLGLOB14R2_SINGLE_RETRY_INSUFFICIENT`

NEXT SAFE STEP: preregister bounded recursive retry-depth attribution.

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
