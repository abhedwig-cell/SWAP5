# Theory-documentation-code-evidence discrepancy register

## Purpose

This register records material differences or unresolved questions among SWAP theory, formal/user documentation, corrected legacy behaviour, SWAP5 implementation and executable evidence.

A discrepancy is not automatically a code defect. It remains open until evidence supports a bounded classification and resolution.

Governing policy: [Quality governance after Status A](../development/quality-governance-a-aa.md).

## Status vocabulary

Use one of:

- `NOT_ASSESSED`
- `INVESTIGATING`
- `DOCUMENTATION_ERROR`
- `LEGACY_CODE_DEFECT`
- `INTENTIONAL_LEGACY_DIFFERENCE`
- `ACCEPTED_SWAP5_DIFFERENCE`
- `AUTHORITY_BINDING_DEFECT`
- `IMPLEMENTATION_DEFECT`
- `UNRESOLVED_SCIENTIFIC_AUTHORITY`
- `BLOCKED_EXTERNAL_AUTHORITY`
- `RESOLVED`

A causal classification must point to evidence.

## Entry template

```text
ID:
PROCESS / COMPONENT:
THEORY / FORMAL AUTHORITY:
DOCUMENTED BEHAVIOUR:
CORRECTED LEGACY BEHAVIOUR:
CURRENT SWAP5 BEHAVIOUR:
EXECUTABLE EVIDENCE:
AFFECTED SOURCE / INTERFACE:
SCIENTIFIC / NUMERICAL IMPACT:
CLASSIFICATION / STATUS:
CANONICAL AUTHORITY:
CANDIDATE SUCCESSOR:
DECISION:
NEXT ACTION:
```

## Open register

| ID | Process / component | Difference | Status | Authority / next action |
| --- | --- | --- | --- | --- |
| TCD-SWAP5-001 | SWAP5-MODFLOW6 lower coupling authority | Application-level coupled-groundwater authority has historically been bound to a production profile requiring `bottom_mode=5`, while the coupling-semantics audit identifies `SWBOTB=5` as prescribed lower-boundary pressure-head realization rather than the groundwater-storage/application authority itself. | INVESTIGATING | Canonical remains unchanged. PR #486 is the noncanonical repair candidate. Qualify CSR-01/02 and reconcile preservation/publication consequences before any admission. |

## TCD-SWAP5-001 decision boundary

The current discrepancy record does **not** decide that the whole SWAP-MODFLOW6 coupling architecture is defective.

The candidate evidence currently distinguishes:

- MODFLOW6 ownership of groundwater state/storage;
- SWAP ownership of unsaturated-zone/process state;
- interface head/flux continuity as coupling conditions;
- a temporary lower-face pressure head as a possible Reference-backend trial realization;
- application-level coupling authority as distinct from a legacy standalone boundary selector.

Until the candidate is qualified and admitted, current canonical implementation remains the executable authority. Publication claims affected by the interpretation remain subject to their own reconciliation.

## Resolution rule

Closing an entry must preserve:

1. what differed;
2. which authority changed or was reinterpreted;
3. whether production source changed;
4. what qualification established the resolution;
5. which historical claims were superseded;
6. which evidence remains valid.

A discrepancy resolution never bypasses the owning production/science workstream or canonical admission process.
