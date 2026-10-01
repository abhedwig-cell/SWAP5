# PPA-WU05-PERCH20 result — perched macropore production admission candidate

Date: 2026-10-01

Status: `QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE`

Canonical baseline:
`integration/f-ci-canonical@f477f3fb7bf272757ac7a764bf9492883a521754`.

Canonical reconciliation merged into candidate:
`integration/f-ci-canonical@42bb867e1da993fe2127d23fe3e449e5244f7407`.

Qualified code/test postimage after reconciliation:
`e07f9302b7f78d2389da1db86648e10aca864b26`.

Qualification run:
`36896827529` — SUCCESS.

## Reconstruction

PERCH20 was reconstructed from current canonical rather than merging the historical
generic A11-A18 research ancestry.

No historical generic A11-A18 status/documentation authority was imported.

The carried production surface is limited to:

- corrected source-faithful perched hydraulic carrier;
- A15 source-faithful exchange derivative;
- A16 read-only current-iterate provider;
- explicit HeadCalc rate/Jacobian callback ABI;
- opt-in inner-Richards serialized runtime route;
- exact source FrReduQ retry ladder;
- minimal serialized observation diagnostics;
- source-backed Andelst admission fixture.

The serialized backend was not overwritten from research ancestry. Current canonical RFM
changes were retained and the inner-route observation fields were added minimally.

## Qualified source-backed authority

The admission fixture is the 112-node Andelst profile reconstructed from the official
SWAP 4.3.1 `cases/3.macroporeflow` package and source.

Baseline Reference Richards, with macropore callback disabled:

- converges;
- nonlinear iterations = 3;
- internal retries = 0;
- integrated mass residual =
  `-1.845358709590128e-10 cm`;
- retains a source-defined perched zone:
  - top node 1;
  - bottom node 29;
  - perched level `0.63031614696426097 cm`;
  - perched bottom level `-28.819658959530571 cm`;
  - ordinary main saturated zone starts at node 56.

## Active inner-Richards perched result

With the production inner route enabled:

- exact source ladder = `[1.0,0.1,0.01,0.001]`;
- attempt 1 at factor 1.0 requests retry;
- attempt 2 at factor 0.1 converges;
- selected index = 1;
- selected factor = 0.1;
- accepted-attempt initial exchange =
  `-1.2839647212405492 cm/d`;
- final exchange =
  `-0.25748894374328285 cm/d`;
- macropore storage gain =
  `5.149778874865657e-4 cm`;
- internal exchange residual = 0;
- macropore balance residual = 0.

The result is identical at `-O0` and `-O2`.

## Transaction ownership

Each source-reduction attempt rebuilds the provider from the same accepted matrix and
seven-field macropore authority.

Failed attempts publish no:

- macropore candidate;
- sorptivity history;
- vertical-flux reconstruction;
- committed state;
- restart state.

Only the first converged factor proceeds to candidate materialization.

The selected reduction factor/index is diagnostic scratch and is not persistent physical
state.

Deterministic replay from the same accepted authority independently selects the same
factor and reproduces matrix candidate, macropore candidate and exchange receipt.

## Default-route preservation

Run `36896827529` passed the complete A7/A8/A9/A10 preservation gate on the same
reconciled branch.

Marker:

`PPA_WU05A10_RAPID_DRAIN_GATE=PASS`.

Thus `inner_richards_exchange_enabled=.false.` preserves the canonically admitted outer
macropore route.

## Admission envelope

Candidate production scope:

- serialized single-column FMR;
- Reference Richards;
- standard `swmbf=1`;
- no covering-layer extension;
- source-faithful perched detection through `CritUndSatVol`;
- current-iterate macropore rates in `vector_F`;
- source-faithful local derivative in `jacobian_F`;
- exact bounded FrReduQ retry ladder;
- candidate-only transaction publication;
- existing seven-field restart state;
- coexistence with already admitted A9 top input and A10 rapid-drain code paths, while
  preserving their existing ownership rules.

Still excluded:

- covering-layer macropore extension;
- within-corrector dynamic crack-volume continuation feedback;
- RossFast macropore execution;
- parallel/concurrent MultiSWAP macropore execution;
- fixed-weir/Ribasim ownership of the same rapid-drain receipt;
- arbitrary/multiple rapid-drain levels beyond A10.

## Decision

`QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE`

The candidate may be proposed to `integration/f-ci-canonical`.

Canonical admission and post-merge preservation remain separate evidence states.
