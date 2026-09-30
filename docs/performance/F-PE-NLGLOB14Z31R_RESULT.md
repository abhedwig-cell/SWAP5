# F-PE-NLGLOB14Z31R result — protocol-correct cumulative-drift attribution re-execution

Date: 2026-09-30

Status:

`QUALIFIED_Z31R_REGIME_LOCALIZED_BIAS`

Qualification authority:

- workflow run: `36757619753`;
- HEAD segment-B job: `110037948169`;
- RUNOFF segment-B job: `110037948275`;
- both segment-B jobs: SUCCESS;
- both trajectories reach 540 d without a frozen physical blocker.

Canonical authority rechecked before persistence:

`integration/f-ci-canonical@c400b02d9956f35c9c20fac09f94b34d5e2ee09f`

The canonical delta since the Z31R baseline is confined to unrelated PZG/SCHED closeout documentation and does not touch the Z31R dependency surface.

Research postimage before result persistence:

`research/f-pe-nlglob14z31r-drift-attribution-reexec@f2a5dadead9a4b38ac9dcac3c62b8a1c9b40393a`

## Aggregate classification

Both fine O05 fixtures independently classify:

`QUALIFIED_Z31R_REGIME_LOCALIZED_BIAS`.

Therefore the cross-fixture aggregate is:

`QUALIFIED_Z31R_REGIME_LOCALIZED_BIAS`.

Z31 remains correctly closed as `BLOCKED_Z31_PROTOCOL_EXECUTION_MISMATCH`; only this separate Z31R re-execution is qualification authority.

## Protocol completion

Both full/adaptive pairs run independently from 140 d to 540 d:

- 6,400,000 accepted nominal intervals per fixture;
- no reduced reconstruction failure;
- no nonlinear solve failure;
- no non-finite state;
- no noncontiguous-tail blocker;
- no ownership jump >1 face;
- adaptive per-interval physical ledger remains far below 5e-8 cm.

A/B state divergence and event timing differences are observed only as diagnostics, exactly as preregistered.

## HEAD

Final state:

- full final tail: `14:16`;
- adaptive final tail: `14:16`;
- ordered event-direction sequence: identical;
- signed final adaptive-full mass difference: about `-1.88933e-5 cm`;
- max adaptive per-interval ledger: about `1.48e-9 cm`;
- deterministic adaptive/full work ratio: `0.80324`;
- mean active dimension: about `12.761`.

Thus deterministic nonlinear algebra work is reduced by about 19.7%.

### Regime attribution

Tail `12:16` / n=12:

- 1,934,939 intervals;
- signed contribution: about `+3.48e-13 cm`;
- RMS interval difference: about `1.03e-15 cm`.

This regime is effectively neutral at machine scale.

Tail `13:16` / n=13:

- 4,058,822 intervals;
- signed contribution: about `-1.86625e-5 cm`;
- mean signed interval difference: about `-4.60e-12 cm`;
- RMS: about `6.52e-10 cm`.

This regime contributes essentially all HEAD long-horizon drift.

Tail `14:16` / n=14:

- 406,239 intervals;
- signed contribution: about `-2.31e-7 cm`.

The first chatter family is negligible. All 16 event intervals together contribute only about `-8.12e-11 cm`; stable intervals dominate the drift.

## RUNOFF

Final state:

- full final tail: `14:16`;
- adaptive final tail: `14:16`;
- ordered event-direction sequence: identical;
- signed final adaptive-full mass difference: about `-3.6840e-7 cm`;
- max adaptive per-interval ledger: about `1.44e-9 cm`;
- deterministic adaptive/full work ratio: `0.80014`;
- mean active dimension: about `12.761`.

Thus deterministic nonlinear algebra work is reduced by about 20.0%.

### Regime attribution

Tail `12:16` / n=12:

- 1,934,888 intervals;
- signed contribution: about `-3.38e-13 cm`;
- RMS about `9.87e-16 cm`.

Again effectively machine-scale neutral.

Tail `13:16` / n=13:

- 4,058,844 intervals;
- signed contribution: about `-1.13703e-6 cm`.

Tail `14:16` / n=14:

- 406,268 intervals;
- signed contribution: about `+7.68633e-7 cm`.

RUNOFF therefore shows partial cancellation after the later transition: the measurable bias first develops in the n=13 / tail 13:16 regime, then the n=14 regime compensates a substantial fraction before 540 d.

The frozen regime-localization criterion still holds, but the mechanistic interpretation must preserve this cancellation rather than treating RUNOFF as a single monotone bias.

## Event timing

The first chatter family remains effectively mass-neutral in both fixtures.

Later 13:16 -> 14:16 transition timing differs between full and adaptive trajectories by small numbers of fine nominal intervals, but:

- both routes retain one-face geometry;
- ordered event-direction sequences agree;
- both settle to the same final tail;
- event intervals themselves are not the dominant cumulative-drift source.

This supports attributing the main issue to stable reduced-regime representation, not chatter suppression or event-publication semantics.

## Performance signal

The trajectory-level adaptive/full deterministic work ratios are:

- HEAD: about 0.803;
- RUNOFF: about 0.800.

This is a robust roughly 20% solver-work reduction across the full 140–540 d independent trajectories.

It is still a deterministic research work metric, not yet production Fortran wall-clock speedup.

## Scientific interpretation

Z31R substantially narrows the remaining problem.

The moving-interface manager architecture itself survives:

- independent adaptive driving reaches 540 d;
- no physical hard blocker occurs;
- same final ownership regime is reached;
- event geometry remains valid;
- per-interval mass accounting remains excellent;
- deterministic solver work is materially reduced.

The remaining discrepancy is localized to the reduced stable-tail representation after the first 12:16 -> 13:16 transition.

The n=12 regime is essentially exact. The n=13 regime creates measurable cumulative A/B drift. In RUNOFF, the subsequent n=14 regime partly cancels it.

This points to an interface-equation / tail-reconstruction discrepancy, not a generic temporal-instability or chatter problem.

## Qualified claim boundary

Qualified:

- protocol-correct independent adaptive/full execution to 540 d;
- regime-localized drift mechanism;
- n=12/tail12:16 effectively neutral;
- first chatter family negligible;
- stable n=13/tail13:16 is the principal onset regime;
- n=14 may partially compensate drift;
- same final tail in both fixtures;
- roughly 20% deterministic solver-work reduction.

Not qualified:

- production admission;
- a corrected n=13 interface equation;
- broader soil/profile portability;
- end-to-end production wall-clock speedup;
- retroactive relaxation of Z30 or Z31 gates.

## Consequence

The next successor should isolate the reduced interface equation for stable tail `13:16` / n=13.

It should compare full and reduced candidates from identical accepted origins and decompose:

1. interface face flux;
2. active guard-node storage term;
3. reconstructed saturated-tail head gradient;
4. lower-tail storage contribution;
5. exact ledger contribution;
6. residual-equation difference.

No correction coefficient or tolerance tuning is authorized.

## Production boundary

Research only.

`LEGACY_NUMERICS` remains production default.
