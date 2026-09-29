# F-PE-NLGLOB14B result — conservative saturation-event split and remainder integration

Date: 2026-09-29

Status:

`CLOSED_TG_EVENT_SPLIT_REMAINDER_DOMAIN_FAILED`

Canonical base:

`integration/f-ci-canonical@ea6a0617ded0c2e6bee89640e090a0aed8a558c2`

Qualification authority:

- workflow run: `36560894595`;
- job: `109381224004`;
- conclusion: SUCCESS.

## Frozen question

Can the qualified NLGLOB14A saturation event be committed as an internal subinterval state and followed by one exact TG remainder trial that completes the original nominal interval?

## Smooth authority

PASS.

The event logic is inactive on the smooth TIMEINT16C bank.

Observed smooth authority remains:

- median refined top-head order about `2.04787`;
- median refined top-theta order about `2.04787`;
- median work ratio versus KLAG BE: `1.0`;
- physical mass and constitutive gates unchanged.

Therefore the event-split implementation itself does not damage the smooth second-order mechanism.

## Target result

All five frozen O05/TG targets reproduce the qualified event localization.

But all five exact remainder trials fail accepted-state retention admissibility.

Remainder domain failures:

`5 / 5`.

Successful complete event splits:

`0 / 5`.

No process failures occur.

Frozen classification:

`CLOSED_TG_EVENT_SPLIT_REMAINDER_DOMAIN_FAILED`.

## Interpretation

The saturation event is correctly localized, but merely restarting the same unsaturated TG accepted-state construction from the event state does not define the post-event temporal problem.

Once the event is reached, the system needs explicit saturated-regime temporal semantics.

This is different from:

- event-time localization;
- timestep-depth subdivision;
- coefficient-stage coordinate choice;
- nonlinear endpoint convergence.

The remainder failure is expected if the unsaturated moisture update continues to treat `theta` as a freely evolving state above a hard constitutive saturation boundary.

## Consequence

Do not add a second saturation event or recursive subdivision.

Open a separate saturated-regime formulation workunit.

The next formulation must define what evolves after `theta = theta_s`, for example pressure head / ponding / flux while saturated storage remains on its constitutive manifold, and how that state couples back to the unsaturated nodes.

It must preserve:

- conservative interval mass;
- provider-consistent endpoint staging;
- transactional event state;
- explicit dynamic-top route semantics;
- smooth second-order behavior when saturation is inactive.

No accepted-theta clipping may be used as a substitute for a saturated state equation.

## Production boundary

Research only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
