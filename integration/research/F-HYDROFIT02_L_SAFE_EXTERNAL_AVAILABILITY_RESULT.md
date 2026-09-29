# F-HYDROFIT02 P-LSAFE02A independent BRO availability audit result

Authority run: `36527719944`, head `af14a57f3ffe92cefe4ca9df37546ad0fcbc5c1c`.

Artifact: `11015427124`, digest `sha256:ce9694bba24cc1b25d0331cabc50b073a29922760aede14362af82082304b0e8`.

## Frozen object set

The audit used exactly the 61 object-independent BRO ids frozen from P-LSAFE02 authority run `36523469252`.

All 61 objects were fetched successfully and received an explicit disposition.

## Availability result

All 61 objects have:

- modelling method `mualemVanGenuchten`;
- modelling procedure `WENRHydrofysicav1`;
- one or more `WaterContentAndConductivityAtSpecificSoilWaterPotential` arrays;
- one or more `ShapeHydraulicConductivityCurve` arrays;
- at least one InvestigatedInterval in which those two arrays are colocated.

Counts:

- frozen objects: 61;
- audited: 61;
- fetch failures: 0;
- objects with MvG method: 61;
- objects with hydraulic arrays: 61;
- objects with shape arrays: 61;
- objects with colocated hydraulic + shape arrays: 61;
- objects with surveyPurpose `bodemfysischOnderzoek`: 0.

Therefore all 61 receive the preregistered exclusion class:

`NO_BODEMFYSISCH_SURVEY_PURPOSE`.

## Survey-purpose distribution

The 61 objects use only:

- `hydrologischOnderzoek`: 38 objects;
- `onbekend`: 23 objects.

No other exclusion mechanism is responsible for the zero-record P-LSAFE02 validation corpus.

## Interpretation

P-LSAFE02's `INSUFFICIENT_INDEPENDENT_BRO_EVIDENCE` result is valid under its frozen population definition.

However, the evidence gap is administrative rather than hydraulic: the independent objects contain the same Mualem-van Genuchten modelling method, the same WENR hydraulic modelling procedure, and the required colocated hydraulic data structures, but carry a different survey-purpose label.

This result does not retroactively broaden P-LSAFE02.

A scientifically distinct follow-up may define eligibility by actual hydraulic record content and modelling semantics rather than by surveyPurpose. Such a study must be separately preregistered before any estimator evaluation.

## Governance

P-LSAFE02 remains closed as:

**INSUFFICIENT_INDEPENDENT_BRO_EVIDENCE**

P-LSAFE02A is closed as a diagnostic availability result.

No production admission follows.
