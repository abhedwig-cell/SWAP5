# F-PE-NLGLOB14R2 result — post-handoff transaction retry recovery

Date: 2026-09-29

Status:

`NLGLOB14R2_SINGLE_RETRY_INSUFFICIENT`

Qualification authority:

- workflow run: `36593061051`;
- job: `109490856854`;
- conclusion: SUCCESS.

Diagnostic amendment authority:

- first exposed run `36592793921`;
- `F-PE-NLGLOB14R2_DIAGNOSTIC_AMENDMENT.md`;
- frozen classifications and numerical policy unchanged.

## Frozen question

Can the existing transaction retry scale `0.5` recover the immediate second TG interval after the accepted first-retreat handoff using one retry decomposition?

## Coverage

PASS.

All 12 O05 six-level fixtures:

- reproduce the nominal second-interval retry-advised outcome;
- restore the accepted second-interval origin exactly;
- use retry scale exactly 0.5;
- enter the first half-dt retry attempt;
- remain finite and accepted-state mass-clean before the rejected retry candidates.

Rollback diagnostics are exactly zero for:

- pressure head;
- water content;
- ponding;
- cumulative accepted ledger;
- cumulative accepted runoff.

## Retry result

In all 12 fixtures, the first half-dt retry attempt again returns retry-advised before producing an accepted endpoint.

Thus:

- no second half is executed;
- no nominal window is recovered;
- no saturation-mode re-entry occurs;
- no hard solver failure occurs;
- no state/mass inconsistency occurs.

Every fixture classifies:

`RETRY_HALF_INTERVAL_STILL_RETRY_ADVISED`.

Frozen aggregate classification:

`NLGLOB14R2_SINGLE_RETRY_INSUFFICIENT`.

## Physical admissibility

Accepted state before the retry sequence remains clean:

- max interval ledger about `2.68e-14 cm`;
- max cumulative ledger about `9.12e-14 cm`.

The negative result is therefore about insufficient retry depth, not accepted-state corruption.

## Scientific interpretation

The accepted first-retreat TG handoff remains viable for one interval.

The following TG interval requires a stronger timestep reduction than one application of the already-qualified 0.5 retry factor.

This does not justify a new retry scale or tolerance change. The existing transaction policy already permits bounded repeated retries with:

- retry scale = 0.5;
- max retries = 8.

The next question is the retry depth required before the second-interval origin produces accepted internal progress.

## Consequence

Open a bounded recursive-retry successor using exactly the existing transaction policy.

It should identify, for each fixture:

- first accepted retry depth;
- accepted internal dt;
- temporal owner at that accepted progress point;
- saturation-mode re-entry if triggered;
- exact rollback before every rejected attempt;
- physical mass.

Do not yet require completion of the full original nominal window in that attribution step.

## Production boundary

Research only.

No production `src/**` change.

No numerical default or temporal-mode ownership changed.

`LEGACY_NUMERICS` remains production default.
