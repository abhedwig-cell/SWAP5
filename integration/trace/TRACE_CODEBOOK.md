# TRACE codebook v0.2

## Structural relation codes

These are preregistered and describe where the contradiction lies, not its cause.

- THEORY_DOCUMENTATION
- THEORY_IMPLEMENTATION
- DOCUMENTATION_IMPLEMENTATION
- INTENDED_EQUATION_EXECUTABLE
- REGRESSION_ORACLE_INDEPENDENT_EVIDENCE
- DUPLICATE_IMPLEMENTATION
- HISTORICAL_CONVENTION_CURRENT_INTERPRETATION
- CALIBRATED_LEGACY_INDEPENDENT_EVIDENCE
- MULTIPLE_RELATION_CONFLICT

## Mechanism code

Open-coded. Do not force a candidate into a pre-existing mechanism. Record a literal description first, then assign or create a mechanism code.

Sensitising concepts only: unit inconsistency, sign drift, indexing, hidden state dependency, temporal staging, duplicated implementation drift, obsolete documentation, incorrect oracle, implicit numerical convention, calibration lock-in, mathematically equivalent but numerically non-equivalent formulation.

## Consequence codes

Potential and demonstrated consequence must be separate.

- INTERPRETATIVE
- QUANTITATIVE
- STRUCTURAL
- CONSERVATION
- NUMERICAL
- APPLICATION_ENVELOPE
- CALIBRATION
- NONE_DEMONSTRATED

## Regression outcome

- REGRESSION_DETECTED
- REGRESSION_MISSED
- REGRESSION_NOT_APPLICABLE
- COUNTERFACTUAL_NOT_RECONSTRUCTABLE

A regression miss requires that the affected route was meaningfully covered by the pre-existing evidence.

## Disposition codes

- IMPLEMENTATION_CORRECTED
- DOCUMENTATION_CORRECTED
- THEORY_CLARIFIED
- REGRESSION_ORACLE_CORRECTED
- LEGACY_BEHAVIOUR_PRESERVED
- BEHAVIOUR_VERSIONED
- RECALIBRATION_REQUIRED
- MODEL_EVOLUTION_REQUIRED
- EQUIVALENCE_DEMONSTRATED
- APPLICATION_ENVELOPE_NARROWED
- UNRESOLVED_INSUFFICIENT_AUTHORITY
- REJECTED_NON_DISCREPANCY

## Coding discipline

Do not infer scientific consequence from the fact that code was changed.
Do not infer correctness from historical regression identity.
Do not assume documentation or theory is authoritative solely because it is published.
Do not split one causal discrepancy into multiple cases because it has multiple manifestations.
Do not merge independent causal discrepancies merely because one work unit discovered them together.

## Pilot-derived v0.2 clarification

`NUMERICAL` is used when the scientific consequence lies in numerical consistency, convergence, solver behaviour or numerical equivalence without implying a changed physical model. `MODEL_EVOLUTION_REQUIRED` is used when available evidence indicates that the scientifically defensible resolution needs new or explicit model state/process representation rather than a local correction to an already-defined implementation contract. These additions were derived only from the historical/pilot corpus before the first prospective case.
