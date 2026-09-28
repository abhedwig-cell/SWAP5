# F-PE-DYNERR01A preregistration — false-safe boundary-transition attribution

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_ATTRIBUTION_RESULTS`

Parent authority:

- DYNERR01 mechanism run `36417846787`;
- 60/64 physical points complete;
- Spearman correlation = 0.4499;
- strict 0.01 cm classifier: 1 false-safe;
- false-safe point: B01/POND, dt=0.02 d, indicator 0.00644 cm versus actual full/two-half head difference 33.81 cm.

DYNERR01 mechanism qualification has already failed. This workunit does not change or rescue those frozen gates.

## Question

Is the severe false-safe associated with a dynamic-top boundary-regime transition that is hidden by evaluating the temporal defect operator only at the full-step endpoint?

## Diagnostic extension

For every existing DYNERR01 point, record independently:

- full-step final dynamic-top regime;
- first-half final regime;
- second-half final regime;
- final top head and ponding for full, half1 and half2.

No equations, indicator values, timestep values, physical gates or solver controls change.

## Classification

A point is a `REGIME_PATH_MISMATCH` when either half-step final regime differs from the full-step final regime, or when half1 and half2 use different final regimes.

The known false-safe is attributed to boundary transition only if it is a REGIME_PATH_MISMATCH.

## Successor rule

- If the false-safe is a REGIME_PATH_MISMATCH, close DYNERR01 as not predictive across dynamic-top regime transitions and open a separately preregistered pre-solve/within-step regime-transition predictor study.
- If not, close DYNERR01 as a direct defect-indicator failure with no transition-predictor inference.

No multiplicative safety factor or threshold fitting is allowed here.
