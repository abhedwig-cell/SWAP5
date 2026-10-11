# F-PE-APPROX04 P1B result — exact participant displacement frontier

Date: 2026-09-26

Status: `NO_COMMON_NONZERO_TRANSACTION_ENVELOPE`

## Protocol

The exact FGC44 participant was tested on the six frozen difficult PROFILE06 origins.

Fresh process per point.

Signed prescribed-head offsets [cm]:

- 0;
- +/-0.001;
- +/-0.0025;
- +/-0.005;
- +/-0.010;
- +/-0.020;
- +/-0.050.

State, material, forcing and numerical controls were aligned to the PROFILE06/P0 authority.

## Result

Exact participant admissibility frontier:

- B01 mid:
  - negative frontier: 0 cm;
  - positive frontier: +0.001 cm.
- B01 wet:
  - negative frontier: 0 cm;
  - positive frontier: 0 cm.
- B12 wet:
  - negative frontier: 0 cm;
  - positive frontier: 0 cm.
- O05 wet:
  - negative frontier: 0 cm;
  - positive frontier: 0 cm.
- O14 mid:
  - negative frontier: 0 cm;
  - positive frontier: 0 cm.
- O14 wet:
  - negative frontier: 0 cm;
  - positive frontier: 0 cm.

Common cross-case frontier:

- negative: 0 cm;
- positive: 0 cm;
- symmetric: 0 cm.

Thus for five of six difficult origins, the exact transaction route rejects even the smallest tested nonzero displacement of 0.001 cm.

## Failure diagnostics

A follow-up test-only diagnostic accessor was added after the initial frontier result, without changing production source. The repeated P1B workflow remained green and reproduced the same admissibility frontier.

For the failing nonzero points:

- participant status is consistently `GW_SWAP_PARTICIPANT_TRIAL_FAILED = 6`;
- kernel/canonical result status is consistently `CANONICAL_STATUS_TRANSACTION_FAILED = 2`;
- the requested interval does not complete and no substep is accepted;
- the transaction exhausts the configured eight retries;
- failures are driven by solver rejections plus temporal-indicator rejections;
- temporal-certificate-unavailable rejections are zero;
- mass rejections are zero.

At the smallest tested nonzero displacement, +/-0.001 cm, this pattern already holds for every failing case. For example:

- B12 wet +/-0.001 cm: 8 solver rejections, 1 temporal rejection, 8 retries;
- O05 wet -0.001 cm: 7 solver rejections, 2 temporal rejections, 8 retries;
- O14 mid +/-0.001 cm: 7 solver rejections, 2 temporal rejections, 8 retries;
- O14 wet +/-0.001 cm: 7 solver rejections, 2 temporal rejections, 8 retries.

B01 mid +0.001 cm is the only nonzero point at the smallest tested magnitude that succeeds. It completes in two accepted substeps after two temporal rejections and no solver rejection.

This narrows the controlling mechanism. The collapsed transaction envelope is not caused by the mass gate or missing temporal authority. It is a retry-exhaustion boundary involving physical solver convergence and temporal acceptance under the exact corrector configuration.

## Interpretation

The offline response function is locally smooth and almost linear, but that fact does not create a usable surrogate domain under the current exact transaction contract.

The controlling limitation is not q(h) approximation error.

It is transaction admissibility of the exact physical trial away from the captured origin under these difficult states.

A response surrogate that accepted displacements where the exact participant itself would reject would bypass, rather than accelerate, current transaction authority.

That is not admissible within APPROX04.

## Decision

Reject the bounded same-origin response-surrogate concept under the current participant semantics.

Do not continue to P1 timing or live coupled implementation.

Any future attempt to exploit local q(h) smoothness first requires a separate scientific/numerical workunit explaining why the exact participant admissibility envelope collapses around these difficult origins and whether that contract is intentionally conservative or reflects another issue.

No surrogate production flag is created.
