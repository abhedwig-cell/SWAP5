# F-MACRO-ALT41 — minimal empirical campaign for discriminating A9 and RFM

Date: 2026-10-01

Status: QUALIFIED_EXPERIMENT-DESIGN_RESULT / MODEL_PHYSICS_FROZEN

Canonical authority: integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

## Purpose

Turn ALT38-ALT40 into the smallest practical empirical campaign that can discriminate the source-faithful A9 direct-entry hypothesis from frozen RFM-RC1.

No model parameter or equation is changed.

## Scoring

The screen uses the canonical A9 default-MvG hydraulic fixture at two controlled top states:

    h = -50 cm
    h = -100 cm

and the realistic Andelst static direct-entry reference:

    A_mp = 0.04.

For each intensity-duration combination, the robust separation score is the smaller of:

    |f_RFM(-50) - 0.04|
    |f_RFM(-100) - 0.04|.

This deliberately favors experiments that remain discriminatory under both hydraulic states rather than one lucky state.

## Main design result

The most informative campaign is not a broad rainfall sweep.

It needs three paired contrasts.

### Pair A — weak short versus long

Recommended:

    R = 4 cm/day
    short ~0.05 day
    long  ~0.50 day

Why:

- current A9 direct fraction remains 4% in both;
- RFM remains strongly matrix-dominated early;
- RFM changes with event age;
- source intensity is low enough to reduce the chance that ponding becomes the dominant confounder.

This pair directly tests the weak-source falsification criterion.

### Pair B — intermediate short versus long

Recommended:

    R = 8 cm/day
    short ~0.05 day
    long  ~0.50 day

Why:

- the event lies near/above the crossover for part of the screened state space;
- RFM predicts a substantial within-event increase in preferential fraction;
- A9 keeps the structural 4% direct fraction;
- the pair therefore tests the dynamic activation mechanism rather than only the zero-activation limit.

### Pair C — continuous versus fragmented

Recommended:

    R = 8 cm/day
    same total source duration ~0.50 day

compare:

    one continuous event
    versus
    two equal separated pulses.

RFM predicts lower total preferential activation for the fragmented case because surface-event age and the sorptivity contribution reset.

The A9 direct atmospheric partition has no equivalent event-age reset in its structural direct fraction.

This is a high-value temporal-memory discriminator.

## Optional strong-event anchor

Add one longer event around:

    R = 15 cm/day

only as an upper-regime anchor.

At strong source both models can produce appreciable preferential entry, so this is less useful for discrimination but useful for confirming that the experiment spans the overlap regime.

## Required observations

Minimum:

- exact applied source intensity and duration;
- antecedent top-state moisture/head;
- ponding/runoff occurrence;
- multi-depth water-content response or conservative tracer;
- independently measured macropore/ped geometry;
- deep/bottom response if available.

Preferred:

- replicate plots;
- spatial antecedent-moisture variability;
- direct dye/path morphology after selected events.

## Acceptance/rejection logic

Support for current direct-area behavior would be increased if:

- weak short events already show an immediate preferential fraction near the structural area fraction;
- short and long events at the same intensity have similar direct-entry fraction after accounting for ponding;
- fragmentation has little effect beyond total applied water.

Support for RFM would be increased if:

- weak short events remain matrix-dominated;
- preferential response grows strongly with duration at fixed source intensity;
- continuous events produce more fast-flow activation than fragmented events with the same total source duration;
- one profile-level sigma_B transfers across the campaign without retuning.

## Campaign size

The decisive core is only six experiments:

    4 cm/day short
    4 cm/day long
    8 cm/day short
    8 cm/day long
    8 cm/day continuous
    8 cm/day fragmented

plus one optional 15 cm/day strong-event anchor.

This is substantially more informative than a large untargeted storm catalogue because every pair isolates a specific model difference.

## Decision

MINIMAL_DISCRIMINATING_CAMPAIGN = DEFINED
PRIMARY_AXIS = DURATION AT FIXED INTENSITY
SECONDARY_AXIS = EVENT FRAGMENTATION
INTENSE_EVENT = OPTIONAL ANCHOR, NOT PRIMARY TEST
MODEL_PHYSICS = REMAIN FROZEN UNTIL DATA

## Next

Do not extend the RFM equations.

Use ALT41 as the acquisition/experimental brief. If an existing dataset contains equivalent paired events, map those events onto this design; otherwise this is the preferred dedicated rainfall-simulator campaign.
