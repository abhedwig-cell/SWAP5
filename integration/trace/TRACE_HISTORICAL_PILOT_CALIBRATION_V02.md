# TRACE historical pilot calibration v0.2

Date: 2026-09-19

Purpose: stress-test the TRACE coding scheme using only discrepancies known before the prospective protocol freeze. These cases are not confirmatory observations and must never be pooled with the prospective corpus.

## Pilot matrix

| Pilot | Evidence basis | Structural relation | Mechanism | Consequence | Regression interpretation | Historical disposition |
|---|---|---|---|---|---|---|
| SWAP-011 | SWAP5 commit `f369e68...`, SWAP-011 finding and qualification dossier | INTENDED_EQUATION_EXECUTABLE; THEORY_IMPLEMENTATION | Jacobian derivative inconsistent with the conductivity relation actually used in the residual | NUMERICAL; potentially QUANTITATIVE | Existing full-run preservation evidence is not sufficient by itself to reconstruct whether the pre-discovery suite would have detected derivative inconsistency; historical pilot therefore does not score RQ2 | IMPLEMENTATION_CORRECTED; physical model unchanged |
| SWAP-012 | SWAP5 commit `94bf490...` | INTENDED_EQUATION_EXECUTABLE | selected forward retention relation and inverse `prhead` use inconsistent model dispatch | STRUCTURAL; QUANTITATIVE | Detected through inverse-consistency contract `prhead(watcon(h)) ~= h`; no confirmatory regression score assigned retrospectively | IMPLEMENTATION_CORRECTED |
| SWAP-013 | SWAP5 commit `c78689f...` | DOCUMENTATION_IMPLEMENTATION; THEORY_IMPLEMENTATION | scalar input validation fails to enforce relational constitutive-domain constraint `0 < HA < H0` | APPLICATION_ENVELOPE; STRUCTURAL | Invalid-domain behaviour is outside ordinary valid-input regression scope unless explicitly tested; no retrospective RQ2 score | IMPLEMENTATION_CORRECTED; application domain made executable |
| ANIMO organic-P redistribution | `integration/animo-prep/PREP01_ORGANIC_P_REDISTRIBUTION_DEFECT.json` | INTENDED_EQUATION_EXECUTABLE; DUPLICATE_IMPLEMENTATION | producer records top-reservoir redistribution but balance consumer omits it | CONSERVATION; QUANTITATIVE | Instrumented conservation accounting and causal source-only probe expose the defect; historical baseline alone is not scored as a regression miss | implementation/accounting defect demonstrated; production correction not yet admitted in the frozen evidence |
| ANIMO NH4 dry-down | `integration/animo-prep/PREP01_NH4_DRYDOWN_LEDGER_SEAM.json` | THEORY_IMPLEMENTATION; INTENDED_EQUATION_EXECUTABLE | remaining dissolved mass has no scientifically adequate conserved state when the surface layer becomes completely dry | CONSERVATION; STRUCTURAL | Event-specific probes expose immediate loss; a local outflow workaround closes the ledger but creates pathological concentration, showing that output matching is not sufficient authority | MODEL_EVOLUTION_REQUIRED |
| ANIMO PO4 numerical conservation | `integration/animo-prep/PREP01_PO4_NUMERICAL_CONSERVATION_SEAM.json` | INTENDED_EQUATION_EXECUTABLE | tangent substitution and nonlinear tolerance allow finite constitutive/storage residual to accumulate | NUMERICAL; CONSERVATION; QUANTITATIVE | Paired numerical probes identify two interacting numerical-policy causes; no retrospective RQ2 classification is forced | evidence supports conservative formulation/tolerance redesign; production correction not yet admitted in the frozen evidence |

## Calibration findings

The v0.1 relation classes were sufficient for all six cases and are unchanged.

Two coding gaps were exposed:

1. `NUMERICAL` is needed because numerical inconsistency can be scientifically relevant without implying that the physical theory changed. SWAP-011 and ANIMO PO4 are the clearest examples.
2. `MODEL_EVOLUTION_REQUIRED` is needed because some discrepancies cannot defensibly be resolved by correcting an implementation of an already-complete model contract. The NH4 dry-down case instead exposes missing conserved physical state.

The pilot also confirms that TRACE must not retrospectively infer `REGRESSION_MISSED` merely because independent evidence later exposed a discrepancy. RQ2 requires an actual reconstruction of the pre-discovery regression scope and execution.

No prospective candidate was registered before this calibration.
