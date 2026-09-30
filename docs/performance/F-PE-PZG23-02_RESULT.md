# F-PE-PZG23-02 — accepted-history causal falsification result

Date: 2026-09-30

Status: QUALIFIED_HISTORY_CAUSE_FALSIFIED

Branch:
`research/f-pe-pzg23-02-history-falsification`

Qualified postimage:
`d0d5b15217854c96bb57a586720da725428952d0`

Canonical baseline:
`integration/f-ci-canonical@021abc51216909de90e992ee917838e3725da1ad`

Workflow run:
`36761908554`

Job:
`110046331564`

Conclusion:
SUCCESS.

## Question

Is the accepted temporal-history vector causal for the two localized pZg23
interval-B failures?

Frozen failing origins:

- origin 10: h0 = +2 cm, delta = +0.035 cm/day;
- origin 11: h0 = +2 cm, delta = +0.050 cm/day.

## Arms

For each origin, interval A was rerun from the frozen initial state and required
to complete and commit.

The accepted A carrier was then exercised through three interval-B arms:

1. ORIGINAL — use the admitted interval-A committed state unchanged;
2. RECON_SAME_HISTORY — reconstruct the exact same physical state with the
   exact accepted temporal-history vector;
3. RECON_ZERO_HISTORY — reconstruct the exact same physical state with a
   zero-valued temporal-history vector of identical shape.

Physical state identity and same-history reconstruction equality were asserted
before interval B.

## Origin 10

### ORIGINAL

- completed = false;
- retries = 16;
- nonlinear iterations = 496;
- backtracking attempts = 2899.

### RECON_SAME_HISTORY

- completed = false;
- retries = 16;
- nonlinear iterations = 496;
- backtracking attempts = 2899.

The solver-work signature is exactly reproduced.

### RECON_ZERO_HISTORY

- completed = false;
- retries = 16;
- nonlinear iterations = 546;
- backtracking attempts = 3206.

Zero history does not recover the case and makes the local nonlinear work
slightly heavier.

## Origin 11

All three arms are identical in completion class and work signature:

- completed = false;
- retries = 19;
- nonlinear iterations = 663;
- backtracking attempts = 3698.

## Hypotheses

H1 — accepted history is causal:

FALSIFIED.

Both zero-history arms still fail.

H2 — hidden solver/warm-start state outside the committed carrier is causal:

FALSIFIED.

ORIGINAL and RECON_SAME_HISTORY reproduce the same failure class and exact
solver-work signature for both origins.

H3 — accepted physical state / local nonlinear regime is causal:

SUPPORTED as the remaining bounded class.

The same accepted physical A-end state fails even when temporal history is
replaced by zeros.

## Classification

`QUALIFIED_PZG23_HISTORY_CAUSE_FALSIFIED_LOCAL_NONLINEAR_REGIME_REMAINS`.

The blocker is not caused by the accepted temporal-history vector and is not a
hidden solver-scratch ownership defect.

## Consequence

Do not:

- reset temporal history in production;
- remove temporal history from the mode-7 policy;
- change the 0.20 cm budget;
- relax hard mass;
- treat reconstruction as a repair.

A successor study may now focus directly on the local nonlinear behavior of the
accepted physical state in interval B.

The most useful next discriminator is solver-local step/backtracking
characterization of the first failing B substep for origins 10 and 11, with the
production tolerances and retry policy unchanged.
