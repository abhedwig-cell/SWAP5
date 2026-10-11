# F-PE-REPAIR01 qualification plan

Date: 2026-09-26

Status: `ACTIVE`

## Q1 — inactive-root poison regression

Run the REPRO01 D8 singleton poison matrix against the repaired production source.

Required:

- ZERO PASS;
- THETA/K/CAPACITY/DKDH PASS;
- ROOT_SINK PASS.

The repaired root-inactive route must be insensitive to deliberately poisoned `provider_root_sink` scratch.

## Q2 — exact first-corrector repeatability

Run the exact/default first-corrector probe repeatedly from one fixed build.

Required:

- no status-6 failures;
- preserved successful solver signature.

## Q3 — fixed-build live repeatability

Use the PROFILE05 fixed-build live SWAP + MODFLOW6 runner.

Required:

- exact 20/20 PASS;
- A2C 20/20 PASS.

This is a robustness gate, not a timing gate.

## Q4 — live A1 and A2C controls

Run:

- existing A1 live MODFLOW E2E control;
- existing A2C live MODFLOW E2E control with at least three independent replicas.

Required:

- endpoint and ledger preservation;
- no candidate-only status-6 failure.

## Q5 — application-shaped A2C preservation

Run the existing APPROX02 application sequence.

Required:

- canonical mass gates preserved;
- endpoint/accounting differences remain within the already-qualified envelope.

## Q6 — root-active semantic preservation

Create paired test-only bridges from the repaired source:

- REPAIRED: production conditional qrosum logic;
- OLD_EQUIVALENT: test copy restores unconditional `sum(provider_root_sink)`.

Set:

- `root_extraction_active=.true.`;
- identical nonzero prescribed root-extraction sink.

Because a root-sink provider is associated in both variants, the new conditional must take the same sum as the old code.

Required:

- same trial status;
- same q;
- same solver diagnostics;
- same accepted endpoint/accounting where available.

## Admission

The repair may close only when all six qualification groups pass.
