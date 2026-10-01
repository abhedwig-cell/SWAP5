# PPA-WU05-PERCH19 result — source-faithful FrReduQ retry ladder

Date: 2026-10-01

Status: `CLOSED_QUALIFIED_SOURCE_FAITHFUL_FREDUQ_RETRY_POLICY`

Baseline:
`research/ppa-wu05-a18-perched-authority-fixture@5434665c34cff570066ccd2d76e10a092f7979d7`

Canonical reconciliation at close:
`integration/f-ci-canonical@641a8ba7fad5b67f0ebff7c78dd065270ed46329`.

Qualified postimage:
`8a238992d37ea640241666b51efc3e1d1a3a6bbb`.

Qualification run:
`36881577203` — SUCCESS.

## Decision

`QUALIFIED_SOURCE_FAITHFUL_FREDUQ_RETRY_POLICY`

The exact B1.11 bounded macropore source-reduction ladder is now owned by explicit
trial-local SWAP5 runtime policy rather than by a qualification fixture.

## Implemented contract

New opt-in policy:

`source_flow_reduction_retry_enabled`

When disabled, the existing inner-Richards route uses the configured rate-template factor
exactly as before.

When enabled, the inner route attempts:

1. `FrReduQ=1.0`;
2. `FrReduQ=0.1`;
3. `FrReduQ=0.01`;
4. `FrReduQ=0.001`.

A retry proceeds only after the Reference-Richards solve explicitly advises retry.

Every attempt is reconstructed from:

- the same accepted matrix state;
- the same accepted seven-field macropore state;
- immutable geometry/configuration;
- the same interval forcing.

Only the first converged attempt proceeds to final rate evaluation, candidate construction,
history update and publication.

The selected factor/index/attempt count are diagnostics, not persistent physical state.

## A18 source-backed proof

On the 112-node Andelst perched authority, the runtime autonomously reports:

- attempts = 2;
- selected index = 1;
- selected factor = `0.1`;
- final runtime status = converged.

The accepted result is identical to the previously qualified A18 fixed-0.1 result:

- initial exchange = `-1.2839647212405492 cm/day`;
- final exchange = `-0.25748894374328285 cm/day`;
- macropore storage gain = `5.149778874865657e-4 cm`;
- internal exchange residual = exactly `0 cm`;
- macropore balance residual = exactly `0 cm`.

Thus the policy reproduces the exact source reduction level required by the authority case
without test-side mutation of `flow_reduction`.

## Accepted-state isolation

The A18/PERCH19 test verifies that the external accepted macropore water state remains
unchanged while the failed 1.0 attempt is discarded and the 0.1 attempt is executed.

No new continuation or restart field is introduced.

## Preservation

Run `36881577203` passes:

- PERCH19 exact retry gate;
- A18 solver-stable perched baseline;
- A16 analytical current-iterate callback;
- A16 actual A11/A15 provider;
- A15 source-faithful derivative;
- full A7/A8/A9/A10 admitted macropore preservation gate.

The default outer route remains unchanged because both
`inner_richards_exchange_enabled` and the new retry policy are opt-in.

## Production implication

The A18 production blocker
`PRODUCTION_INNER_ROUTE_LACKS_SOURCE_FAITHFUL_FREDUQ_RETRY_STATE_MACHINE`
is closed.

The perched line now has qualified research evidence for:

- source-backed distinct perched topology;
- solver-stable Reference-Richards baseline;
- current-iterate inner macropore exchange;
- source-faithful derivative treatment;
- serialized transaction ownership;
- source-faithful bounded FrReduQ retry.

## Canonical admission boundary

PERCH19 is not directly merged from this ancestry.

Canonical advanced during the research line and now owns generic `PPA-WU05-A11` paths
for a different RFM workunit.

Any admission candidate must therefore be reconstructed from current canonical and carry
forward only the required perched code plus uniquely namespaced PERCH evidence/tests.

The frozen Status-A denominator remains unchanged.
