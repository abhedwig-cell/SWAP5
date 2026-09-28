# F-PE-DYNERR02 preregistration — dynamic-top transition-guard practical classifier

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@3b94726fe7d01aec42a5a53587769f38916203f4`

Parent authority:

- F-PE-DYNERR01: `CLOSED_DYNAMIC_TOP_INDICATOR_NOT_PREDICTIVE`;
- DYNERR01A: severe false-safe attributed to dynamic-top regime-path mismatch;
- BOFEK practical P-C1 envelope remains the target accuracy class.

## Purpose

Test whether the dynamic-top defect indicator can still be useful as a cheap bounded practical safe/unsafe classifier when combined with an explicit boundary-regime transition guard.

This is not a scientific local-error estimator and does not generalize the fixed-flux production indicator.

## Cheap transition guard

For a requested dynamic-top interval, evaluate the same dynamic-top provider at the accepted origin state using:

- accepted origin top pressure head;
- accepted origin water content;
- accepted origin ponding as candidate ponding;
- the requested step duration;
- the same forcing and fixed-K parameters.

Record this as `origin_regime`.

After the full candidate solve, record `full_regime`.

A candidate step is automatically classified UNSAFE when:

`origin_regime != full_regime`.

Only same-regime candidates may be classified by the defect indicator.

No half-step information participates in the classifier. Half steps exist only as offline truth for this research workunit.

## Practical local truth

For calibration, a complete full versus two-half point is `ACTUALLY_SAFE` only if all are true:

- max pressure-head endpoint difference <= 2.0 cm;
- ponding endpoint difference <= 0.02 cm;
- runoff-depth difference <= 0.02 cm;
- storage endpoint difference <= 0.02 cm;
- all ledgers satisfy <= 5e-8 cm.

Otherwise it is `ACTUALLY_UNSAFE`.

These bounds are frozen before DYNERR02 result exposure.

## Calibration bank

Reuse the already exposed DYNERR01 mechanism bank:

- 16 hydraulic/regime cases;
- requested dt = 0.005, 0.010, 0.020, 0.040 d;
- up to 64 points.

This bank is development/calibration only.

## Frozen indicator thresholds

Test independently:

- 0.25 cm;
- 0.50 cm;
- 1.00 cm;
- 2.00 cm;
- 4.00 cm.

Classifier:

`CLASSIFIED_SAFE = same_regime AND indicator <= threshold`.

## Advancement gates

A threshold can advance only if:

1. at least 48 complete truth points exist;
2. zero false-safe points:
   `CLASSIFIED_SAFE AND ACTUALLY_UNSAFE`;
3. safe coverage >= 50% of complete truth points;
4. at least 25% of WET/POND complete points are classified safe;
5. no mass/ledger failure is hidden by classification.

Selection among advancing thresholds:

1. highest safe coverage;
2. tie-break lower threshold.

If none advances, close DYNERR02 with no classifier gain.

## Validation

If one threshold advances:

1. freeze it immediately in a committed result/validation preregistration;
2. construct a new, previously unexposed 16-case validation bank;
3. keep the classifier unchanged.

Validation requires:

- zero false-safe;
- safe coverage >= 40%;
- every hydraulic archetype contributes at least one classified-safe point;
- mass/ledger preserved.

Only then may the classifier be called:

`PRACTICAL_DYNAMIC_TOP_CLASSIFIER_RESEARCH_ONLY`.

## Production boundary

No production `src/**` change in DYNERR02.

No timestep authority is granted by calibration alone.
