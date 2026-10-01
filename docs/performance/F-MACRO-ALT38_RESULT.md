# F-MACRO-ALT38 — A9 versus RFM crossover regime map

Date: 2026-10-01

Status: QUALIFIED_RESEARCH_REGIME_MAP / EXPERIMENT-DESIGN RESULT

Canonical authority: integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

## Identity

For source-faithful A9 direct vertical entry:

    q_A9 = A_mp * R

For frozen RFM-RC1:

    q_RFM = f_pref(h,R,tau) * R

Therefore exact equality occurs at:

    A_mp,crossover = f_pref(h,R,tau)

ALT38 maps this crossover at tau=0.25 day using the canonical A9 default-MvG parameter fixture and sigma_B=0.65.

## Selected crossover fractions

At h=-100 cm:

    R=1   -> A_mp,cross ~0.0000
    R=2   -> ~0.0004
    R=4   -> ~0.0078
    R=8   -> ~0.067
    R=15  -> ~0.236
    R=30  -> ~0.513
    R=60  -> ~0.739

At h=-50 cm:

    R=4   -> ~0.016
    R=8   -> ~0.110
    R=15  -> ~0.316
    R=30  -> ~0.591

At h=-10 cm:

    R=4   -> ~0.003
    R=8   -> ~0.035
    R=15  -> ~0.157
    R=30  -> ~0.416

## Interpretation

For any actual A9 top-area fraction A_mp:

- if A_mp is above the crossover, A9 predicts more direct preferential entry than RFM;
- if A_mp is below the crossover, RFM predicts more preferential entry than A9;
- near the crossover, top-entry amount alone is not a strong discriminator and depth/timing evidence becomes more important.

## Highest-value empirical regime

Weak unponded forcing is the cleanest discriminator.

For source rates around 1-4 cm/day, RFM predicts near-zero preferential activation across the screened hydraulic states, while A9 predicts a fixed nonzero fraction whenever structural macropore area exists.

This is scientifically much more informative than very intense events, where RFM preferential fractions become large and can overlap plausible A9 area fractions.

## Strong-event regime

At 30-60 cm/day the crossover area becomes roughly 0.4-0.8 over much of the screened state range.

Thus very intense events alone cannot distinguish the models cleanly: both may predict large preferential entry, though for different reasons.

## Experiment-design consequence

The preferred discriminating dataset should contain, for the same structural profile:

1. at least one weak unponded event;
2. one intermediate event near the crossover;
3. one intense event;
4. antecedent hydraulic state;
5. a deep-response or tracer observable.

The key falsification question is not merely whether preferential flow exists, but whether substantial deep response occurs during weak input when RFM matrix intake capacity remains high.

## Decision

PAIRED_REGIME_BOUNDARY = MAPPED
WEAK_EVENT = HIGHEST DISCRIMINATION VALUE
INTENSE_EVENT_ONLY DATA = INSUFFICIENT FOR MODEL CHOICE
NO PARAMETER RETUNING = PERFORMED

## Next

Use this map to prioritize event-level empirical acquisition and, when available, stratify ALT35 calibration/hold-out events by distance from the A9/RFM crossover rather than by rainfall intensity alone.
