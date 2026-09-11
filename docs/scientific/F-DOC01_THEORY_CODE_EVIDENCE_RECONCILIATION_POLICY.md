# F-DOC01 theory-code-evidence reconciliation policy

Theory, documentation, code and evidence are independent evidence sources. A disagreement is an object to resolve, not a reason to choose the most convenient source silently.

## Discrepancy classes

- `CONSISTENT`
- `THEORY_CORRECT_CODE_DEFECT`
- `CODE_CORRECT_DOCUMENTATION_DEFECT`
- `LEGACY_IMPLEMENTATION_BEHAVIOUR_REQUIRES_SCIENTIFIC_REVIEW`
- `THEORY_AMBIGUOUS`
- `IMPLEMENTATION_AMBIGUOUS`
- `INTENTIONAL_MODEL_CHANGE`
- `LEGACY_DEFECT_CORRECTED`
- `EVIDENCE_INSUFFICIENT`
- `UNRESOLVED_BLOCKS_STATUS_A`

## Mandatory discrepancy record

Each discrepancy records: stable ID, capability/scope, theory authority, documentation authority, code authority, evidence authority, observed difference, scientific assessment, uncertainty, disposition, required follow-up workunit, qualification evidence, affected releases and status.

## Decision rules

1. Legacy behaviour is descriptive evidence, not automatic scientific authority.
2. A code-derived equation is labelled `SOURCE_CODE_RECONSTRUCTION`; it is not transformed into a literature citation.
3. A corrected SWAP 4.3.1 defect is documented as `LEGACY_DEFECT_CORRECTED`, including old behaviour, scientific basis for correction and qualification authority.
4. An intentional scientific change requires an explicit decision record and old→new theory/implementation/qualification chain.
5. F-DOC01 never repairs production behaviour. Code defects discovered here are routed to a dedicated scientific/production workunit.
6. A material unresolved discrepancy in the scientific chain is `UNRESOLVED_BLOCKS_STATUS_A` for the affected capability.

Reconciliation does not mean forcing theory and code to look identical. It means the relationship, approximation and evidence are explicit enough to audit.
