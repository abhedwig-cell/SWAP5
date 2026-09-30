# F-PE-ELASTIC60 — mode-7 transaction-core composition result

Date: 2026-09-30

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic60-transaction-composition`

Qualified postimage:
`52a5fea4f313a5b5b383a9dc7197cb920d8aaf09`

Canonical baseline:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Workflow run:
`36703179491`

Job:
`109847155320`

Conclusion:
SUCCESS.

## Question

Can the production transaction core correctly compose:

- the mode-7 research defect indicator;
- frozen `alpha = 0.17320259355765216`;
- ELASTIC59 calibrated threshold
  `T_BOUND = 0.049428424452890203 cm`;
- C-SAFE geometric refinement;
- hard mass acceptance;
- rollback/retry;
- commit only after all gates pass?

## Equivalent native certificate budget

The production model-certificate transaction surface consumes a normalized
model-owned indicator.

ELASTIC60 therefore used the exact equivalent native Binf budget:

`B_NATIVE = T_BOUND / alpha = 0.2853792396384496 cm`.

Certificate:

`Binf / B_NATIVE`.

Accepted when:

`certificate <= 1`.

No threshold or alpha was refit.

## Transaction authority

ELASTIC60 used the production `execute_reference_interval` implementation with:

`TX_TEMPORAL_MODEL_CERTIFICATE`.

Only the model seam was qualification-only because the production mode-7
temporal indicator remains deliberately fail-closed.

The research model used:
- production Reference Richards solver;
- ELASTIC53 research mode-7 defect indicator;
- transactional previous-right-derivative history;
- exact solver top/bottom fluxes for mass accounting.

No `src/**` production source changed.

## Frozen cases

Holdout profile:
`3030`.

States:
- `h0=-20 cm`;
- `h0=+10 cm`.

Perturbations:
- `delta=-0.035 cm/day`;
- `delta=+0.035 cm/day`.

Regimes:
- OFF;
- FIXED_1E6;
- GENERATED.

Total:
`12` transaction cases.

Requested interval:
`0.015625 day`.

Retry:
- factor 0.5;
- maximum 8 retries.

## Independent first-pass oracle

For every case an independent direct-solve oracle replayed the same retry
ladder from the original initial state and zero initial temporal derivative.

An oracle trial passed only when:
- solver converged;
- hard mass residual <= 1e-12 cm;
- mode-7 indicator was available;
- certificate <= 1.

The production transaction core had to reproduce both:
- accepted/exhausted classification;
- first-passing dt.

It did so for all 12 cases.

## Accepted unsaturated cases

All six `h0=-20 cm` cases accepted the requested full interval:

`dt = 0.015625 day`.

Typical normalized certificates:

- delta -0.035: `0.803403`;
- delta +0.035: `0.805141`.

For these unsaturated cases OFF/FIXED/GENERATED are physically identical
because ELAS is inactive below saturation.

## Saturated negative perturbation

### OFF

`h0=10, delta=-0.035`:

- independent oracle: EXHAUSTED;
- transaction: EXHAUSTED;
- attempts: 9;
- retries: 8;
- rollbacks: 9;
- commits: 0;
- solver rejections: 9.

No failed trial leaked state.

### FIXED_1E6

Accepted at:

`dt = 0.000244140625 day`.

Transaction:
- attempts: 7;
- retries: 6;
- rollbacks: 6;
- commits: 1;
- temporal rejections: 6;
- normalized accepted indicator: `0.705548`;
- hard mass residual: approximately `8.53e-16 cm`.

### GENERATED

Accepted at:

`dt = 0.0009765625 day`.

Transaction:
- attempts: 5;
- retries: 4;
- rollbacks: 4;
- commits: 1;
- temporal rejections: 4;
- normalized accepted indicator: `0.683818`;
- hard mass residual: approximately `3.41e-15 cm`.

## Saturated positive perturbation

### OFF

`h0=10, delta=+0.035`:

- independent oracle: EXHAUSTED;
- transaction: EXHAUSTED;
- attempts: 9;
- retries: 8;
- rollbacks: 9;
- commits: 0;
- solver rejections: 2;
- temporal rejections: 7.

### FIXED_1E6

Accepted at:

`dt = 0.000244140625 day`.

- attempts: 7;
- retries: 6;
- rollbacks: 6;
- commits: 1;
- solver rejections: 1;
- temporal rejections: 5;
- normalized accepted indicator: `0.705548`;
- hard mass residual approximately `-7.96e-15 cm`.

### GENERATED

Accepted at:

`dt = 0.0009765625 day`.

- attempts: 5;
- retries: 4;
- rollbacks: 4;
- commits: 1;
- temporal rejections: 4;
- normalized accepted indicator: `0.683818`;
- hard mass residual approximately `1.08e-14 cm`.

The accepted mass residual remains well within the frozen 1e-12 cm hard gate.

## Transaction semantics qualification

All gates passed:

- A1 12 cases executed;
- A2 O0/O2 semantic identity;
- A3 transaction classification matched independent oracle;
- A4 accepted dt matched first-passing oracle dt exactly;
- A5 solver + hard mass + model certificate all required before commit;
- A6 rollback/retry accounting and state isolation;
- A7 accepted committed state bit-identical to independent direct accepted trial;
- A8 deliberate mass-defect discriminator rejected before commit and preserved
  initial state;
- A9 zero production source change.

## Interpretation

ELASTIC60 closes the transaction-semantics uncertainty.

The calibrated mode-7 certificate can be composed with the existing production
transaction core without weakening:

- mass conservation;
- rollback;
- first-passing geometric refinement;
- commit isolation;
- accepted-state identity.

The remaining gap is not transaction logic.

It is production shaping of the serialized Reference backend, which currently
continues to fail closed for bottom-mode-7 temporal-indicator evaluation.

## Decision

Classification:

`QUALIFIED_MODE7_TRANSACTION_CORE_COMPOSITION`.

No production admission is authorized by ELASTIC60.

The next bounded workunit should production-shape the mode-7 indicator inside
the serialized Reference backend while preserving:

- current fail-closed envelope outside bottom mode 7 / swkimpl=0;
- existing mode-2/mode-5 indicator semantics;
- temporal-history state layout;
- model-certificate transaction route;
- hard mass and rollback behavior;
- default-off/reference preservation.

That workunit may become an admission candidate only after independent
preservation and end-to-end runtime qualification.
