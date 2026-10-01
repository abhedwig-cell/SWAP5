# F-MACRO-ALT53 — absolute bromide recovery and f_MB identifiability bound

Date: 2026-10-01

Status: QUALIFIED_MASS-CLOSURE_BOUND / DIRECT_f_MB_FROM_MISSING_TRACER_REJECTED

Canonical authority: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

## Purpose

Use source-supported applied/recovered bromide mass information from the Weiherbach tracer experiments to determine what can and cannot be inferred about RFM f_MB.

## Source-supported experiment mass closure

The Weiherbach experiments used:

    plot area = 1.4 m x 1.4 m
    bromide concentration in irrigation water = 0.165 kg/m3

For the macroporous preferential-flow sites:

Spechtacker:

    irrigation duration = 02:30
    irrigation intensity = 11.1 mm/h
    reported recovery rate = 95%

Site 33:

    irrigation duration = 02:20
    irrigation intensity = 9.7 mm/h
    reported recovery rate = 96%

The experimental literature identifies both as Colluvic Regosols with abundant worm burrows.

The profile sampling extends to approximately 1 m depth.

## Immediate mass-balance implication

The unrecovered fraction of applied bromide is therefore only:

    Spechtacker: ~5%
    Site 33:     ~4%

This rules out any model configuration in which a substantially larger fraction of total applied conservative tracer leaves the sampled system irreversibly below the profile without appearing in the measured recovery.

## Why missing mass is not f_MB

RFM f_MB is defined as:

    fraction of preferential input assigned to persistent continuous/deep pathways.

It is NOT defined as:

    fraction of total applied tracer missing below 1 m.

The relationship contains at least three additional factors:

    F_pref
      = fraction of applied source entering preferential flow;

    E_MB
      = fraction of MB tracer exchanged/retained in the sampled matrix/profile;

    X_MB
      = fraction of the remaining MB tracer that actually exits below the sampled depth.

A schematic conservative bound is:

    F_missing
      >= F_pref * f_MB * (1 - E_MB) * X_MB

only if other loss terms are negligible.

Conversely, the measured 4-5% missing mass gives an upper constraint on the product:

    F_pref * f_MB * survival_to_below_profile

not on f_MB alone.

## Identifiability consequence

Even with absolute applied/recovered tracer mass, f_MB remains confounded with:

1. surface activation magnitude sigma_B through F_pref;
2. wall exchange / matrix retention along MB pathways;
3. finite sampling depth and bottom-exit probability;
4. unmeasured lateral or analytical recovery losses.

Therefore the shortcut:

    f_MB = 1 - recovery_fraction

is physically invalid.

ALT53 explicitly rejects it.

## What the recovery data are good for

The high recovery rates are valuable as a hard forward-model gate.

For any future full RFM tracer simulation of Spechtacker/site 33:

    recovered tracer within sampled profile
    + modeled tracer leaving below profile
    + any explicitly represented external loss
    = applied tracer

and modeled below-profile loss must remain compatible with the observed 4-5% unrecovered envelope.

This will strongly constrain combinations of:

    sigma_B,
    f_MB,
    wall exchange,
    and routing speed

once the full forward tracer model exists.

## Relation to ALT51/ALT52

ALT51/ALT52 establish that the normalized retained tracer mass profile strongly constrains the endpoint-shape parameter p.

ALT53 shows that absolute recovery adds a second, independent constraint:

    normalized shape -> p_eff
    total recovered fraction -> deep-loss product constraint

but still does not uniquely identify f_MB.

This is the correct decomposition of the available information.

## Decision

    SPECHTACKER_ABSOLUTE_RECOVERY = AVAILABLE_95_PERCENT
    SITE33_ABSOLUTE_RECOVERY = AVAILABLE_96_PERCENT
    BELOW_PROFILE_TOTAL_TRACER_LOSS = STRONGLY_BOUNDED
    f_MB_EQUALS_MISSING_FRACTION = REJECTED
    f_MB_DIRECTLY_IDENTIFIED = NO
    f_MB_COMPOSITE_FORWARD_CONSTRAINT = YES

## Next

The next scientifically useful implementation is no longer another dataset search.

Build a frozen full RFM conservative-tracer forward harness with explicit ledger terms:

    applied tracer
    matrix-retained tracer
    IC endpoint tracer
    MB wall-exchanged tracer
    MB below-profile tracer
    residual fast-domain tracer

and require exact mass closure.

Then test whether one parameter set can satisfy simultaneously:

1. Spechtacker Profile 1 depth mass;
2. held-out Profile 2 depth mass;
3. 95% total recovery;
4. the measured macropore depth structure.

Only that forward problem can determine whether f_MB becomes identifiable after p is constrained.
