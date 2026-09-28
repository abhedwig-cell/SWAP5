# F-PE-EMBEDSTEP01 preregistration — selective embedded full-versus-two-half control

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority: `integration/f-ci-canonical@7b73f4545f79e3e3575ed21d9c94d3d5a21e3ea9`.

Parent authority:

- BOFEK strict line: no static strict policy gain;
- BOFEK practical line: large timestep gains exist but static regime/material policies are not robust enough;
- STATESTEP01-03: normalized accepted-state history can reduce work by ~34% on passing cases, but cannot robustly predict wet/surface transitions.

## Purpose

Test a selective embedded temporal-error guard around the promising normalized state-aware controller.

The aim is to pay full-versus-two-half cost only when the controller proposes a timestep larger than the current Reference DTMAX.

No production source change in this workunit.

## Base adaptive proposal

Use the STATESTEP02 normalized accepted-step signal:

`r_h = max_i(|h_i(t1)-h_i(t0)| / max(10 cm, |h_i(t0)|))`

with frozen target:

`R = 0.40`.

Next-step proposal:

`factor = clamp(sqrt(R/max(r_h,1e-12)),0.5,2.0)`

`dt_proposed = clamp(dt*factor,DTMIN,4*DTMAX_reference)`.

First step uses the Reference geometric initial dt.

## Selective embedded trigger

No embedded check when:

`dt_proposed <= DTMAX_reference`.

When:

`dt_proposed > DTMAX_reference`

the next attempted interval is checked by computing from the same accepted origin:

1. one full-step trajectory over dt;
2. two sequential half-step trajectories over dt/2 + dt/2.

The half-step route carries the intermediate dynamic-top ponding state exactly.

## Embedded error metric

For completed full and two-half routes calculate:

- `E_h = max_i |h_full_i - h_half_i|`;
- `E_pond = |pond_full - pond_half|`;
- `E_runoff = |runoff_full - runoff_half|`.

The embedded check passes only if all frozen thresholds pass.

Three candidate embedded envelopes are screened:

- E025:
  - E_h <= 0.25 cm
  - E_pond <= 0.005 cm
  - E_runoff <= 0.005 cm
- E050:
  - E_h <= 0.50 cm
  - E_pond <= 0.010 cm
  - E_runoff <= 0.010 cm
- E100:
  - E_h <= 1.00 cm
  - E_pond <= 0.020 cm
  - E_runoff <= 0.020 cm

No threshold is moved after result exposure.

## Acceptance semantics

If the embedded check passes:

- accept the full-step state;
- count the two-half work as guard overhead;
- continue the normalized adaptive proposal.

If the check fails but both half steps solve:

- accept the two-half endpoint as the more temporally resolved route;
- count one temporal guard rejection;
- set next dt no larger than the half-step duration.

If the full step or either half step fails:

- do not commit that route;
- reduce dt by the existing failure factor and retry from the accepted origin.

Mass ledger must pass independently for every committed full or half substep.

## Calibration bank

Reuse the already exposed 16 BOFEK01 screening cases only for envelope selection.

Comparator is current corrected adaptive Reference.

P-C1 accuracy gates remain unchanged.

## Advancement rule

A candidate envelope advances only if:

- at least 15/16 P-C1 cases pass;
- every WET/POND case passes;
- median total deterministic work reduction versus Reference >=15%, including all embedded guard solves;
- no retry pathology.

Selection among advancing envelopes:

1. highest median work reduction;
2. tie-break tighter envelope.

If none advances, close selective embedded control.

If one advances, freeze it before constructing a new validation bank.

## Production boundary

Research-only. Even a successful candidate can only become `PRACTICAL_MODE_CANDIDATE_RESEARCH_ONLY` here.
