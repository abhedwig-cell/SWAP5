# F-MACRO-ALT40 — duration signature of A9 direct entry versus RFM

Date: 2026-10-01

Status: QUALIFIED_RESEARCH_DURATION_DISCRIMINATION_RESULT

Canonical authority: integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

## Purpose

Exploit the most important difference exposed by ALT39 at realistic A_mp=0.04:

    A9 direct fraction is structurally fixed at 4%

while:

    RFM cumulative preferential fraction evolves during a continuous event because b50(tau) decreases as the transient sorptivity contribution decays.

## Controlled setup

Use the canonical A9 hydraulic parameter fixture at fixed h=-100 cm, sigma_B=0.65 and the official Andelst static surface fraction A_mp=0.04.

This is a mechanistic isolation test. The matrix hydraulic state is deliberately held fixed so the duration signature of the activation law is not mixed with full Richards-state evolution.

## Result

For low source rates, RFM remains below the 4% direct-area reference even over long duration.

Representative cumulative behavior:

At R=2 cm/day:

    RFM stays effectively below 4% over the screened 2-day event.

At R=4 cm/day:

    early event: far below 4%
    0.25 d: still below 4%
    1 d: remains below or near the threshold

At R around 5-6 cm/day:

    the event can cross the 4% reference only after a finite duration.

At R=8 cm/day:

    RFM starts below 4% but crosses the reference during the event and ends clearly above it.

At R=15 cm/day:

    the crossover occurs early and RFM quickly exceeds the 4% direct-area route.

## Core discriminator

The two models predict qualitatively different within-event behavior under constant unponded source.

A9/current direct-area mechanism:

    q_pref/R = A_mp = constant

from the start of the event.

RFM:

    q_pref/R starts low
    rises with source-event age
    may or may not cross A_mp depending on source intensity and duration

This duration dependence exists even when total source intensity is held constant.

## Why this matters experimentally

A paired set of same-intensity events with different durations is a cleaner discriminator than comparing unrelated storms.

Highest-value design:

1. same structural profile;
2. same source intensity;
3. one short pulse;
4. one long pulse;
5. no ponding;
6. antecedent state controlled or observed;
7. multi-depth/tracer response.

If preferential response fraction is essentially established immediately and remains source-proportional, that supports the area-partition concept.

If short pulses remain mostly matrix-dominated while longer pulses progressively recruit fast flow, that supports RFM activation.

## Interaction with event fragmentation

ALT23 already predicted that splitting one event into multiple pulses reduces total RFM activation because each pulse restarts the early-time sorptivity contribution.

Combined with ALT40, this gives a second strong signature:

    one continuous event
      versus
    same total water split into separated pulses

at equal nominal source intensity.

Current A9 direct vertical partition is much less sensitive to this event-age reset mechanism because the source-proportional direct fraction is structural.

## Decision

DURATION_SIGNATURE = STRONG_DISCRIMINATOR
SAME_INTENSITY_SHORT_VS_LONG = PRIORITY_EXPERIMENT
EVENT_FRAGMENTATION = PRIORITY_SECONDARY_EXPERIMENT
FULL_RICHARDS_REPLAY = NOT REQUIRED TO ESTABLISH THIS MECHANISTIC CONTRAST

## Next

ALT41 should combine intensity and duration into a compact experimental design matrix and rank candidate tests by expected A9-RFM separation. The output should be a minimal empirical campaign, not another model change.
