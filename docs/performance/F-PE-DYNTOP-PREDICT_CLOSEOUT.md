# F-PE-DYNTOP-PREDICT01-03 closeout — cheap dynamic-top large-step classifier

Date: 2026-09-28

Final status:

`CHEAP_DYNAMIC_TOP_CLASSIFIER_VALIDATED_RESEARCH_ONLY`

Current canonical authority:

`integration/f-ci-canonical@79dde9d93fe17dd686ba9902eca2bd0ab0d2f26b`

## Evidence chain

### PREDICT01 — origin-frozen surface state

27 labelled large intervals:

- 19 safe;
- 8 unsafe.

Every preregistered surface-only rule had:

- 100% safe coverage;
- 4 false safe.

Conclusion:

origin-frozen boundary regime/ponding/runoff information alone is not a safe gate.

### DYNERR01 parallel authority

Canonical DYNERR01 independently established that extending the existing temporal defect indicator to dynamic top is not predictive enough:

- Spearman correlation about 0.45;
- one severe false-safe;
- the severe false-safe traversed FLUX -> HEAD across the two-half route.

PREDICT does not reopen that rejected indicator.

### PREDICT02 — two-step accepted history

Adding cheap accepted-state history produced one advancing rule.

H0:

- requires two-step history;
- requires no origin-frozen runoff potential;
- requires `r_last <= 0.10`.

Calibration:

- 31 labels;
- false safe = 0;
- safe coverage = 57.1%.

### PREDICT03 — blind validation

On a new forcing/state bank:

- 24 labels;
- false safe = 0;
- safe coverage = 52.4%;
- all four hydraulic archetypes represented;
- 7 WET/POND labels.

Therefore H0 validates under the frozen classifier criteria.

## What has been learned

The main difficulty near wet transitions is not captured well by:

- static soil classes;
- static regime classes;
- absolute accepted head movement;
- simple top-head thresholds;
- origin-frozen surface regime alone;
- endpoint-only dynamic-top temporal defect.

A short accepted history does materially improve discrimination.

The useful cheap signal is not an error estimate in the formal sense. It is a conservative classifier of whether a proposed large interval is worth attempting without expensive temporal refinement.

## Architecture boundary

TIMEARCH01 is now canonical authority and requires explicit ownership separation before a new controller is selected for production.

TIMEARCH02 is already preregistered on its own branch and owns executable timestep decision contracts and the shadow-controller seam.

Therefore PREDICT does not directly alter legacy TimeControl.

H0 should be treated as an input candidate for a later shadow proposal/controller qualification after the TIMEARCH decision contracts exist.

## Production boundary

No production `src/**` changes.

No change to:

- BOFEK00 correctness;
- Reference TimeControl;
- DTMIN/DTMAX defaults;
- BALTOL02;
- TEMPORAL08;
- solver tolerances;
- event scheduling;
- retry ownership.

## Recommended continuation

After TIMEARCH02 has qualified the explicit proposal/event/retry contracts:

1. run H0 as a shadow large-step classifier with no trajectory effect;
2. attribute how often it would release or block proposals above the legacy Reference ceiling;
3. compare projected work against the conservative split route;
4. only then preregister an executed adaptive-controller qualification on new holdout workloads.

Final classification:

`CHEAP_DYNAMIC_TOP_CLASSIFIER_VALIDATED_RESEARCH_ONLY`.
