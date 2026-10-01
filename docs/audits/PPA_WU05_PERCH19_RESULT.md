# PPA-WU05-PERCH19 result — source-faithful FrReduQ retry ladder

Date: 2026-10-01

Status: `CLOSED_QUALIFIED_SOURCE_FAITHFUL_FRREDUQ_RETRY_LADDER`

Research baseline:
`research/ppa-wu05-a18-perched-authority-fixture@0988aa61b0467923f4b0dcdde4a8a83156a18d5e`.

Canonical reconciliation at start:
`integration/f-ci-canonical@f477f3fb7bf272757ac7a764bf9492883a521754`.

Qualified postimage:
`4a5de7e2532c91b02147eb060dc62579d68eb908`.

Qualification run:
`36894849478` — SUCCESS.

## Decision

`QUALIFIED_SOURCE_FAITHFUL_FRREDUQ_RETRY_LADDER`

The exact B1.11 macropore convergence-reduction ladder is now represented as bounded,
trial-local runtime policy for the inner-Richards macropore route.

This research branch is not itself an admission branch because its ancestry contains the
historical generic A11-A18 namespace that now collides with later canonical RFM authority.

## Exact source contract

The runtime uses exactly:

`PERCH_SOURCE_REDUCTION_LADDER = [1.0, 0.1, 0.01, 0.001]`.

This is the B1.11 contract:

`FrReduQ = 0.1 ** IDecMpRat`, with `IDecMpRat=0..3`.

No intermediate factor and no factor below 0.001 is permitted.

## Trial-local ownership

Every reduction attempt:

1. starts from the unchanged `base_request`;
2. rebuilds the inner provider from the same accepted seven-field macropore state;
3. applies exactly one source factor to all macropore exchange-rate families;
4. executes Reference Richards;
5. discards solver/provider scratch when retry is requested.

Macropore candidate construction, sorptivity-history publication and vertical-flux
reconstruction occur only after the first converged factor.

The reduction index/factor is returned only as runtime diagnostics:

- `inner_reduction_attempts`;
- `inner_reduction_index`;
- `inner_reduction_factor`.

It is not added to persistent/restart state.

## Andelst authority result

On the A18 112-node source-backed perched authority:

- attempt 1 at factor `1.0` requests retry;
- attempt 2 at factor `0.1` converges automatically;
- selected reduction index = 1;
- selected factor = `0.1`;
- initial accepted-attempt exchange =
  `-1.2839647212405492 cm/d`;
- final exchange =
  `-0.25748894374328285 cm/d`;
- macropore storage gain =
  `5.149778874865657e-4 cm`;
- internal exchange residual = 0;
- macropore balance residual = 0.

The accepted values reproduce A18's manually stepped source-ladder result.

## Deterministic replay

The same accepted matrix/macropore authority was executed twice.

Both executions independently selected:

- 2 attempts;
- reduction index 1;
- factor 0.1;

and reproduced matrix candidate, macropore candidate and final exchange receipt within the
existing strict test tolerances.

Marker:

`PPA_WU05_PERCH19_DETERMINISTIC_REPLAY=PASS`.

This supports the decision that the reduction index is recomputable trial policy rather
than restart state.

## O0/O2

The Andelst qualification is identical at `-O0` and `-O2`.

Marker:

`PPA_WU05_PERCH19_ANDELST_O0_O2=PASS`.

## Preservation

Run `36894849478` also passed:

- A17 inner transaction infrastructure;
- A16 analytical callback;
- A16 actual provider;
- A15 source-faithful derivative;
- corrected perched carrier;
- complete A7/A8/A9/A10 default macropore route.

Final default-route marker:

`PPA_WU05A10_RAPID_DRAIN_GATE=PASS`.

Therefore the source ladder does not alter the default outer macropore route.

## Production decision

The scientific/numerical prerequisite identified by A18 is closed.

The perched chain now has research qualification for:

- source-backed solver-stable perched authority;
- current-iterate inner-Richards exchange;
- source-faithful derivative semantics;
- serialized transaction/reject/replay/restart infrastructure;
- exact source convergence-reduction ladder;
- active perched mass closure.

The next step is an admission reconstruction from then-current canonical under the
`PPA-WU05-PERCH*` namespace.

Only the required implementation/evidence may be carried forward. Historical generic
A11-A18 status/docs must not overwrite the later canonical RFM namespace.
