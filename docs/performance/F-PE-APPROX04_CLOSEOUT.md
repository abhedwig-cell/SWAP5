# F-PE-APPROX04 closeout — bounded same-origin response surrogate

Date: 2026-09-26

Status: `CLOSED_REJECTED_BY_TRANSACTION_AUTHORITY`

PR:
`#641 — F-PE-APPROX04: bounded same-origin response surrogate`

Branch:
`work/f-pe-approx04-response-surrogate`

Parent:
`F-PE-PROFILE06`

## Purpose

APPROX04 tested whether intermediate same-origin coupling correctors could avoid repeated physical Richards solves by using a bounded local q(h) representation, while retaining an exact final validation trial before commit.

## P0

Offline mode-5 response characterization was positive.

Across six difficult PROFILE06 origins:

- response orientation remained stable over +/-0.5 cm;
- worst q-prediction error relative to exact q excursion was about 0.79%;
- worst tangent drift was about 1.57%.

A conservative +/-0.25 cm research envelope reduced the worst excursion-relative q error to about 0.39% and tangent drift to about 0.78%.

The local response function was therefore smooth enough to justify a transaction-level prototype attempt.

## P1A

When the same difficult states were moved into the real FGC44 transaction participant, the proposed +/-0.25 cm envelope immediately failed exact participant admissibility.

After reconciling the fixture to the PROFILE06/P0 state and forcing authority, the exact participant rejected a +0.05 cm B01-wet corrector.

This demonstrated that local approximation accuracy and transaction admissibility are distinct constraints.

## P1B

The exact participant displacement frontier was then measured directly using fresh processes and offsets down to +/-0.001 cm.

Result:

- five of six difficult cases rejected every tested nonzero displacement;
- B01-mid accepted only +0.001 cm and no tested negative displacement;
- common cross-case nonzero frontier: none.

## Scientific conclusion

The response-surrogate idea is not blocked by local q(h) smoothness.

It is blocked by the current exact transaction admissibility envelope on difficult origins.

Follow-up P1B diagnostics identify the immediate failure mechanism more specifically: failing nonzero trials return `GW_SWAP_PARTICIPANT_TRIAL_FAILED` / `CANONICAL_STATUS_TRANSACTION_FAILED`, accept no substep, and exhaust all eight configured retries. The retry stream contains solver rejections and temporal-indicator rejections, while mass rejections and temporal-certificate-unavailable rejections remain zero. B01-mid +0.001 cm is the lone smallest-offset nonzero success and completes through two accepted substeps after temporal retrying.

Under current semantics, a surrogate that served nonzero displacements would answer requests for which the exact physical participant itself rejects the trial.

That would change coupling/transaction meaning rather than accelerate an accepted computation.

APPROX04 therefore rejects the surrogate route.

## Performance implication

The remaining repeated Reference solve cost identified by PROFILE06 is real, but it cannot currently be removed through this local-response shortcut without first understanding the exact participant's near-zero admissibility frontier.

That issue is now a numerical/transaction-semantics question, not a performance implementation task.

## Decision

No production surrogate.

No new approximation flag.

No source implementation changes.

If pursued further, the next workunit should diagnose the difficult-origin exact participant failure boundary itself:

- why zero displacement succeeds;
- why O(1e-3 cm) displacement frequently fails;
- why the exact corrector repeatedly reaches retry exhaustion from a mix of solver and temporal-indicator rejections under tiny head perturbations;
- whether the strict HEAD_BUDGET / transaction retry policy is intentionally defining this near-zero admissibility envelope or exposing a numerical pathology;
- why B01-mid +0.001 cm can recover through temporal substepping while the other difficult origins cannot;
- and whether that behavior is intended physical/numerical policy.

Only after that question is resolved should response-surrogate performance work be reconsidered.
