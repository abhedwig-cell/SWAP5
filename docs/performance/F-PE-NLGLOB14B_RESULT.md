# F-PE-NLGLOB14B result — conservative saturation-event split and remainder integration

Date: 2026-09-29

Status:

`CLOSED_SATURATION_EVENT_SPLIT_REMAINDER_INSUFFICIENT`

Canonical base:

`integration/f-ci-canonical@ea6a0617ded0c2e6bee89640e090a0aed8a558c2`

Canonical rechecked before result persistence:

`integration/f-ci-canonical@262190047ff97399cb1368cf45d7965dedf6de86`

The intervening canonical movement does not change the NLGLOB14B temporal test harness or event authority.

Qualification authority:

- workflow run: `36561069471`;
- job: `109381802775`;
- conclusion: SUCCESS.

## Frozen question

Can a nominal interval that crosses the accepted TG saturation boundary be completed conservatively by:

1. localizing the event with NLGLOB14A;
2. retaining the admissible event state;
3. reevaluating the dynamic-top provider at the event;
4. integrating the exact remaining fraction with the same TG construction?

## Smooth authority

PASS.

The smooth TIMEINT16C bank remains strongly second order:

- median refined top-head order: `2.04787`;
- median refined top-theta order: `2.04787`;
- 4/4 individual head ladders >=1.5;
- physical mass at roundoff;
- work ratio versus KLAG BE: `1.0`.

Thus event-split machinery does not damage the smooth non-event temporal mechanism.

## Event-target result

Frozen primary event targets:

`5`.

Completed after event split:

`0 / 5`.

Every primary event target localizes the first saturation event, but the remainder subinterval immediately encounters another accepted-state saturation crossing.

Across the full 96-case diagnostic bank:

- event-split attempts: `8`;
- second-crossing failures: `8`;
- successful complete event splits: `0`;
- full-bank completion: `88 / 96 = 0.91667`;
- process failures: `0`.

## Physical admissibility

The failure is not mass-related.

Observed maxima over completed trajectories:

- max accepted-interval ledger about `4.84e-14 cm`;
- max cumulative ledger about `6.06e-14 cm`.

Event subinterval ledgers remain at roundoff scale.

All completed states are finite.

## Frozen classification

`CLOSED_SATURATION_EVENT_SPLIT_REMAINDER_INSUFFICIENT`.

The preregistered negative gate applies because the event remainder fails by a second saturation crossing in all primary targets.

## Scientific interpretation

NLGLOB14A solved the event-time localization problem.

NLGLOB14B shows that the remaining issue is the **post-event regime formulation**.

After the first accepted TG saturation event, restarting the same unsaturated TG temporal construction over the remainder is not physically appropriate for this bank: it immediately tries to cross saturation again.

The next formulation must therefore treat the localized event as a regime boundary.

The remainder needs explicit saturated/dynamic-top temporal semantics rather than recursive reuse of the pre-event unsaturated accepted-state construction.

This is not evidence for:

- deeper subdivision;
- recursive bisection as timestep control;
- accepted-theta clipping;
- a looser retention domain.

## Consequence

Open:

`F-PE-NLGLOB14C — post-saturation remainder regime formulation`.

The successor must be formulation-first and preregistered before result exposure.

It must define:

1. event state ownership at `theta = theta_s`;
2. the saturated storage/pressure-head relation after the event;
3. how the dynamic-top boundary supplies flux/head/runoff during the remainder;
4. how the remainder derivative is formed without asking the unsaturated retention inverse to represent `theta > theta_s`;
5. full nominal-interval physical mass accounting;
6. route transition semantics at the event;
7. smooth second-order preservation when the event path is inactive.

No production implementation is authorized until this post-event regime qualifies test-only.

## Production boundary

Research only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
