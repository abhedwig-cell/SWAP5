# F-MACRO-ALT48 — HILLSCAPE quantitative same-event SSF receipt

Date: 2026-10-01

Status: QUALIFIED_QUANTITATIVE_EXTERNAL_RECEIPT / f_MB_DIRECT_IDENTIFICATION_REJECTED

Canonical authority: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

## Purpose

Execute the ALT47 mass-based observation operator on the user-supplied HILLSCAPE dataset:

    2021-011_Maier-van-Meerveld_Data.zip

The target is a continuous observed fast-routing receipt, not a binary PF label.

## Observed quantities

HILLSCAPE Table 7 supplies, for each sprinkling experiment:

- rainfall intensity;
- total shallow subsurface-flow runoff ratio:
  
      Q_SSF / P_applied

- event-water fraction in SSF:

      f_e

from two- or three-component isotope hydrograph separation.

The associated Water Resources Research paper defines `f_e` as the fraction of applied rainfall water in the measured SSF.

## Frozen ALT48 operator

The directly observed same-event-water SSF receipt fraction is:

    F_new,SSF
      = (Q_SSF / P_applied) * f_e

This is the fraction of applied rainfall that exits the trench as same-event water during the experiment.

No RFM parameter appears in this observation operator.

## Dataset result

Number of controlled SSF experiments with the required quantities:

    n = 18

Observed:

    minimum F_new,SSF  = 0.0018  (~0.18%)
    median             = 0.03075 (~3.08%)
    mean               = 0.09272 (~9.27%)
    maximum            = 0.3159  (~31.59%)

The dynamic range spans almost two orders of magnitude.

This is substantially more quantitative than dye morphology or binary PF occurrence.

## Selected paired intensity sequences

Several plots have repeated low/middle/high sprinkling experiments.

Examples:

Susten 10k, central:

    24 mm/h -> ~2.90% same-event SSF receipt
    43 mm/h -> ~3.99%

Susten 10k, left:

    26 mm/h -> ~2.20%
    33 mm/h -> ~7.60%

Susten 1990, central:

    14 mm/h -> ~2.64%
    33 mm/h -> ~31.59%
    46 mm/h -> ~25.76%

Susten 1990, right:

    15 mm/h -> ~28.86%
    37 mm/h -> ~15.36%
    48 mm/h -> ~30.25%

Klausen 1940, left:

    46 mm/h -> ~0.71%
    60 mm/h -> ~3.25%

Therefore a simple monotone intensity-to-fast-receipt relation is not universal at plot scale.

## What ALT48 identifies

`F_new,SSF` is a genuine mass-based external receipt.

It is useful for testing whether a fast-domain model can produce the correct order of magnitude and event sensitivity for rapid external routing.

It can constrain a composite quantity of the form:

    preferential entry fraction
      x
    probability/fraction of fast water routed to the trench SSF outlet.

## What ALT48 does NOT identify

ALT48 explicitly rejects:

    F_new,SSF == f_MB

because RFM `f_MB` is the persistent continuous/deep pathway fraction of preferential input, whereas HILLSCAPE measures shallow lateral SSF collected in a trench.

The mapping is affected by:

- lateral redistribution;
- soil storage and mixing;
- saturation state;
- trench capture geometry;
- deep percolation not captured by the trench;
- overland flow;
- previous-event water.

Likewise:

    F_new,SSF != surface preferential-entry fraction

without an independent vertical source-partition measurement.

## Scientific value

HILLSCAPE closes an important gap from ALT47:

    a continuous observed fast-water receipt exists.

However it identifies a downstream routing receipt rather than the RFM surface activation parameter sigma_B or the MB structural fraction in isolation.

The result is still valuable because any future coupled RFM hillslope/export adapter should reproduce this receipt range without using f_MB as a free compensator for surface activation errors.

## Decision

    HILLSCAPE_CONTINUOUS_MASS_RECEIPT = PASS
    EVENT_WATER_SSF_RECEIPT_OPERATOR = QUALIFIED
    DIRECT_SIGMA_B_IDENTIFICATION = NO
    DIRECT_f_MB_IDENTIFICATION = NO
    COMPOSITE_FAST_ENTRY_X_ROUTING_CONSTRAINT = YES

## Next

The highest-value remaining dataset is GFZ/Hartmann for the frozen p depth-shape operator.

If the GFZ zip is uploaded, execute:

    trinary dye -> normalized depth centroid / deep stained fraction / max depth

without using stained area to fit sigma_B.

For HILLSCAPE itself, a later model-composition experiment may compare modeled fast external receipt against F_new,SSF after an explicit hillslope/trench routing owner exists.
