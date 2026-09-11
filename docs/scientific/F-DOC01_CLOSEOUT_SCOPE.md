# F-DOC01 closeout scope

F-DOC01 qualifies the architecture for version-controlled SWAP5 scientific documentation, Status A/AA requirement mapping and theory-to-code-to-evidence traceability. It does not populate a complete scientific dossier and it does not confer a WUR quality status.

## Qualified architecture scope

The workunit establishes:

- a T0 through T14 scientific traceability spine from physical phenomenon to exact release authority;
- stable scientific IDs and versioning rules;
- explicit theory, conceptual-model, equation, discretisation, numerical-method, software-contract, implementation, verification, validation, qualification and release relationships;
- source and input provenance policies;
- parameter and calibration documentation contracts;
- sensitivity, uncertainty and fitness-for-purpose documentation architecture;
- ownership and maintenance schemas;
- theory, documentation, code and evidence discrepancy governance;
- a public 22-requirement Status A/AA mapping baseline with the formal 2024 authority kept separate and fail-closed;
- machine-readable schema contracts for future traceability and readiness registries.

## Explicit nonclaims

F-DOC01 does **not** claim:

- `STATUS_A_COMPLIANT`;
- `STATUS_AA_COMPLIANT`;
- `SWAP5_HAS_STATUS_A`;
- `STATUS_A_QUALIFIED`;
- `READY_FOR_STATUS_A_REVIEW`;
- completion of all T0-T14 records for production capabilities;
- completion of model-wide validation, sensitivity, uncertainty or fitness-for-purpose evidence;
- completion of organisational ownership and maintenance evidence;
- that the publicly inspectable 22-requirement text is identical to the controlled `Revised checklist Status A/AA, 2024`.

## Formal blocker

The controlled full criterion authority `WR-QA-2024` was not obtained by F-DOC01. Its exact wording and any differences from the public 22-requirement baseline must be reconciled before readiness or compliance terminology can advance. Evidence completion and the competent WUR audit process remain separate later gates.

## Exit target

If the F-DOC01 fail-closed exact-head CI is green, the maximum decision is:

`QUALIFIED_SCIENTIFIC_DOCUMENTATION_TRACEABILITY_ARCHITECTURE_READY_FOR_INCREMENTAL_POPULATION`

Follow-on workunits may populate scoped scientific traceability records and build release-bound documentation dossiers. They must not mutate historical evidence authority or silently promote this architecture qualification into Status A/AA compliance.
