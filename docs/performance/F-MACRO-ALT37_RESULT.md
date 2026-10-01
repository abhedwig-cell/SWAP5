# F-MACRO-ALT37 — first paired source-faithful A9 vs RFM shadow comparison

Date: 2026-10-01

Status: QUALIFIED_PAIRED_RESEARCH_COMPARISON / PHYSICS_DIVERGENCE_EXPOSED

Canonical authority: integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

## Resume trigger

After RFM-RC1 closeout, canonical advanced to PPA-WU05-A10. The admitted A9 source-faithful top-input route now provides a real reference receipt for direct macropore top entry.

This satisfies the shadow-comparison resume condition.

## Paired fixture

The comparison uses canonical A9/F-SI04 fixture values:

    accepted matrix head = -100 cm
    direct atmospheric source = 1.25 cm/day
    explicit lateral overland source = 0.10 cm/day
    top static macropore volume = 0.50 cm
    top compartment thickness = 0.50 cm

Hence the A9 source-faithful top-area fraction is:

    A_mp = 0.50 / 0.50 = 1.0

and the reference direct vertical macropore entry is exactly:

    q_ref,vertical = 1.25 cm/day

or 0.00125 cm over the A9 dt=0.001 day.

The lateral 0.10 cm/day route is kept separate because RFM activation governs direct effective infiltrating source rather than the separately owned lateral-overland receipt.

## Same-state RFM hydraulics

Using the exact A9 default-MvG parameter fixture at h=-100 cm gives approximately:

    theta = 0.2293
    K_surface = 0.1428 cm/day
    S_surface = 12.63

so early-event b50 is extremely large because of the capillary term.

## Paired result

With frozen sigma_B=0.65 and source rate 1.25 cm/day:

At event age 0.0005 day:

    A9 reference direct macro fraction = 1.000
    RFM preferential fraction          = ~0
    delta vertical macro rate          = about -1.25 cm/day

At 0.01 day RFM remains effectively zero.

At 0.25 day RFM preferential fraction is only about 2.4e-5.

Even at 1 day it is only about 0.001.

## Meaning

This is not a numerical mismatch between equivalent formulations. It exposes the central physical difference between the models.

A9/current SWAP direct entry:

    structural macropore area present
      -> fixed source-proportional direct entry

RFM-RC1:

    source competes with current matrix intake capacity
      -> weak source is taken almost entirely by matrix
      -> preferential entry activates only when effective source exceeds distributed matrix capacity

The A9 fixture is intentionally extreme because its top-area fraction equals one, but that makes the distinction unambiguous.

## Scientific consequence

The shadow result strongly reinforces the ALT13/ALT14 falsification target:

    weak-event preferential flow is the decisive discriminator.

If field data show immediate substantial deep preferential response under weak unponded forcing in a profile whose matrix intake capacity is high, RFM activation is falsified.

If weak forcing remains matrix-dominated and preferential response rises mainly with effective intensity/duration, the fixed-area direct-entry reference mechanism is less supported.

## No model tuning

No RFM parameter was changed to reduce the delta.

No reference geometry was changed.

The separately owned lateral-overland receipt was not folded into RFM source activation.

## Decision

REAL_A9_REFERENCE_RECEIPT = AVAILABLE
PAIRED_SHADOW_COMPARISON = PASS
REFERENCE_VS_RFM_TOP_ENTRY = STRONGLY DIVERGENT
DIFFERENCE_CLASS = PHYSICAL_HYPOTHESIS, NOT IMPLEMENTATION_ERROR

## Next

Repeat the paired comparison over a bounded grid of top-area fractions, matrix heads and source intensities using the same canonical A9 source equation and frozen RFM-RC1 contract.

The goal is to map the exact regime boundary where both formulations agree versus diverge, without calibrating either model. That regime map can then define the highest-value empirical experiments.
