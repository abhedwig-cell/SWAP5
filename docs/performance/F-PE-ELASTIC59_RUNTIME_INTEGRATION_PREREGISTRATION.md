# F-PE-ELASTIC59 — production-shaped mode-7 certificate runtime integration preregistration

Date: 2026-09-30

Status: PREREGISTERED_RESEARCH_ONLY

Parent authority:
`F-PE-ELASTIC58 — QUALIFIED_MODEL_CERTIFICATE_TRANSACTION_AND_WORK_ADVANTAGE_RESEARCH_CANDIDATE`

Parent postimage:
`research/f-pe-elastic58-transaction-cost@d9da601dc47bf4f8f43554870eea421acaad573b`

Canonical authority:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

## Purpose

Run the first production-shaped serialized Reference transaction using:
- bottom mode 7;
- GENERATED ELAS;
- temporal-history continuation;
- `TX_TEMPORAL_MODEL_CERTIFICATE`;
- the ELASTIC53 research mode-7 defect-indicator operator;
- the ELASTIC54/55 frozen global scaling.

Compare it against the current exact-identity
`TX_TEMPORAL_EXTERNAL_FULL_HALF` route on the same requested interval.

No production default or committed production source is changed.

## Research-only mode-7 runtime patch

Canonical production still fails closed for bottom mode 7 in
`mod_reference_richards_temporal_indicator`.

ELASTIC59 may temporarily patch the CI checkout copy of that source only for
qualification:
- admit bottom mode 7 in the existing boundary envelope;
- retain mode-5-only Dirichlet bottom stiffness;
- introduce no other operator change.

The file must be restored before the source-scope gate.

No `src/**` change may be committed.

## Frozen physical case

Use the real ELASTIC46-55 source profile:
- BRO normalsoilprofile `90116260`;
- frozen BRO artifact from run `36550782840`;
- same 16-node variable grid;
- admitted generated ELAS prior;
- bottom mode 7;
- swkimpl=0;
- fixed-flux top boundary.

Regime:
- GENERATED only.

Initial state:
- h0 = +10 cm.

Perturbations:
- delta = +0.05 cm/day;
- delta = -0.05 cm/day.

Requested interval:
- `dt_requested = 0.015625 day`.

Frozen retry:
- scale 0.5;
- max retries 8.

## Research head budget

Use:
`head_budget = 0.10 cm`.

Frozen global scaling:
`alpha = 0.17320259355765216`.

The serialized runtime expects a direct Binf budget, therefore supply:

`model_temporal_indicator_budget = head_budget / alpha`.

This is a research budget only, not a production temporal limit.

## Temporal-history bootstrap

For the certificate route initialize the committed state with
`FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY`
and an accepted predecessor right derivative equal to zero, representing the
preceding equilibrium state used in ELASTIC53-58.

The exact-identity comparison route uses normal committed state and
`FMR_NUMERICAL_CONTINUATION_NONE`.

## Primary runtime expectations

For each perturbation:

Certificate route:
- temporal indicator enabled;
- predecessor derivative available;
- certificate available on converged attempts;
- one extra tridiagonal solve per evaluated certificate;
- no extra full nonlinear trajectory for the certificate itself;
- retries are one-way halving;
- final accepted dt satisfies the research budget;
- hard mass gate passes;
- exactly one external commit.

Identity route:
- preserves the current exact-state comparison;
- no relaxed criterion;
- expected to exhaust or fail to commit over the same retry envelope.

These are hypotheses, not predeclared outcomes.

## Timing

Matched production-shaped timing:
- O2 only;
- 5 replicas;
- fresh committed state per interval;
- same two perturbations;
- same requested dt;
- same initialization work in both routes except temporal-history state type;
- at least 20 interval calls per replica.

Report wall-clock nanoseconds per requested interval.

Timing is CI-local and not a portable benchmark.

## Gates

A1. Temporary mode-7 indicator patch is exactly scoped and restored.

A2. O0/O2 non-timing runtime classifications/counters agree.

A3. Certificate route preserves hard mass acceptance.

A4. Certificate-unavailable remains fail-closed in a dedicated negative case
with temporal history intentionally absent.

A5. Certificate route never adds an extra full nonlinear trajectory for the
indicator.

A6. Identity route remains exact-identity semantics.

A7. Timing uses fresh independent state per call and identical requested
interval/case count.

A8. Zero committed `src/**` production changes.

## Decision

ELASTIC59 may qualify a production-shaped runtime research candidate and a
matched CI timing result.

It does not authorize:
- production mode-7 indicator admission;
- the 0.10 cm research head budget;
- default-on model-certificate temporal mode;
- replacement of the current production temporal gate.
