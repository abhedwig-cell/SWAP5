# F-MACRO-ALT39 — realistic 4% macropore-area crossover

Date: 2026-10-01

Status: QUALIFIED_RESEARCH_REGIME_RESULT / WEAK-EVENT DISCRIMINATION_SURVIVES_REALISTIC_AREA

Canonical authority: integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

## Purpose

ALT37 used the deliberately extreme A9 test fixture with top macropore area fraction equal to one. ALT39 asks whether the same physical contrast survives a realistic structural surface fraction.

The official Andelst case recorded in ALT11 has:

    VLMPSTSS = 0.04
    PPICSS   = 0.5

so the static total macropore surface fraction is 0.04.

For the direct atmospheric component the current SWAP/A9 hypothesis therefore predicts:

    q_ref / R = 0.04

before any dynamic crack contribution.

ALT39 combines that source-backed structural fraction with the canonical A9 default-MvG hydraulic fixture. This is a structural sensitivity comparison, not a full Andelst replay.

## Exact crossover question

We solve:

    f_pref_RFM(h,R,tau,sigma_B=0.65) = 0.04

for source rate R.

Below the crossover source rate, current SWAP direct-area entry is larger than RFM activation. Above it, RFM is larger.

## Results

At h=-100 cm:

    tau=0.01 d -> crossover R ~18.0 cm/day
    tau=0.10 d -> crossover R ~7.0 cm/day
    tau=0.25 d -> crossover R ~6.2 cm/day
    tau=0.50 d -> crossover R ~5.9 cm/day
    tau=1.00 d -> crossover R ~5.8 cm/day

At h=-50 cm:

    tau=0.01 d -> crossover R ~13.3 cm/day
    tau=0.10 d -> crossover R ~5.4 cm/day
    tau=0.25 d -> crossover R ~4.8 cm/day
    tau=1.00 d -> crossover R ~4.5 cm/day

At h=-10 cm:

    crossover remains higher at early event age because the retained state has high matrix conductivity/capacity; source must still become several cm/day before RFM exceeds the 4% direct-entry reference.

## Main result

The weak-event discriminator is not an artifact of the A9 fixture having A_mp=1.

With a realistic 4% static surface fraction, current SWAP still predicts a fixed 4% direct macropore entry at arbitrarily weak positive source, whereas RFM predicts less than 4% until source intensity crosses a state- and event-age-dependent threshold.

For the canonical A9 hydraulic fixture that threshold is typically of order:

    ~5-7 cm/day after the early event transient

for h around -50 to -100 cm.

At very early event age the crossover can be much higher because the capillary sorptivity term is strongest.

## Scientific consequence

The highest-value observation window is therefore not limited to extremely weak rainfall. Even moderate source rates below roughly 5 cm/day can discriminate the models for this hydraulic fixture.

Current SWAP predicts:

    fixed structural fraction immediately

RFM predicts:

    near-zero at event start
    then increasing activation as transient matrix intake capacity decays

That also creates a duration-dependent signature at fixed rainfall intensity that the direct-area route does not possess.

## Caveat

Dynamic shrinkage can increase the current SWAP surface macropore area above the static 0.04. If so, the reference/RFM divergence becomes larger, not smaller, for weak source.

Conversely, the exact crossover values are hydraulic-profile dependent and must not be treated as universal rainfall thresholds.

## Decision

REALISTIC_4_PERCENT_REFERENCE = TESTED
WEAK_EVENT_DIVERGENCE = RETAINED
EARLY_EVENT_DURATION_SIGNATURE = STRONG
UNIVERSAL_INTENSITY_THRESHOLD = NOT CLAIMED

## Next

ALT40 should exploit the new duration signature directly: compare equal-intensity events of different duration under the 4% reference and RFM. The reference direct fraction remains 4%, while RFM activation should evolve during the event. This is likely an even cleaner empirical discriminator than intensity alone.
