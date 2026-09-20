# Status-A to Status-AA evidence planning register

## Purpose

SWAP5 has an admitted frozen Status-A review baseline. This register tracks evidence and governance gaps for later Status-AA assessment without altering that frozen baseline.

Governing policy: [Quality governance after Status A](quality-governance-a-aa.md).

This is an internal planning register. It is **not** a formal Status-AA claim and does not replace an authoritative external WUR/WOT quality checklist.

## Evidence states

Use these internal states:

- `FROZEN_STATUS_A_AUTHORITY`
- `CURRENT_EVIDENCE_PRESENT`
- `NEEDS_FORMAL_MAPPING`
- `PARTIAL`
- `GAP`
- `BLOCKED`
- `NOT_APPLICABLE` with justification

Do not treat implementation as equivalent to independent evidence or formal qualification.

## Current planning domains

| Domain | Internal state | Current repository basis | Next evidence action |
| --- | --- | --- | --- |
| Frozen Status-A baseline | FROZEN_STATUS_A_AUTHORITY | `992a5c657...`; `docs/status-a/**`; `docs/review/**` | Preserve immutable denominator and review provenance |
| Scientific/conceptual description | CURRENT_EVIDENCE_PRESENT | curated science pages, Status-A traceability and review portal | Map exact external criteria when checklist is selected |
| Architecture and implementation traceability | CURRENT_EVIDENCE_PRESENT | ADRs, invariants, Status-A architecture, capability admission records | Formal criterion mapping and independent review |
| Verification and regression evidence | CURRENT_EVIDENCE_PRESENT | F-CI/F-VQ/testbank/capability-specific qualification evidence | Consolidate criterion-to-evidence index without duplicating authority |
| Theory-documentation-code reconciliation | PARTIAL | F-DOC authority reconciliation, TRACE research, discrepancy policy | Maintain concrete discrepancy records and resolution evidence |
| Mass conservation / transaction ownership | CURRENT_EVIDENCE_PRESENT | mass-accounting contract, transaction architecture and preservation evidence | Formal criterion mapping |
| Variables / parameters / units / ownership | PARTIAL | typed contracts and capability-local documentation | Decide whether a canonical registry is needed and define bounded scope |
| Precision policy | PARTIAL | existing double-precision and mass-accounting practice; governance rule now explicit | Record canonical kind/precision ownership before mixed-precision research |
| Input/output and provenance | PARTIAL | exact Git/reference provenance strong; application-data provenance distributed | Inventory application-data/config provenance requirements |
| Validation against observations | NEEDS_FORMAL_MAPPING | validation studies and application evidence exist outside one quality map | Inventory accepted datasets/publications and application domains |
| Sensitivity analysis | NEEDS_FORMAL_MAPPING | research evidence distributed | Map existing evidence and identify missing domains |
| Uncertainty analysis | PARTIAL | numerical-uncertainty workstream and other research lines active | Separate numerical, parameter, forcing and structural uncertainty evidence |
| Applicability and limitations | CURRENT_EVIDENCE_PRESENT | bounded capability claims, nonclaims, publication claim ledgers | Consolidate against formal criteria |
| Version/configuration management | CURRENT_EVIDENCE_PRESENT | canonical branch, immutable qualification records, PROJECT-CONTROL | Define release-level quality mapping |
| Maintenance / ownership / continuity | PARTIAL | workstream ownership and PROJECT-CONTROL exist | Formalize organizational ownership/support evidence if required |
| User documentation | CURRENT_EVIDENCE_PRESENT | strict MkDocs review portal and current docs | External quality review against selected checklist |
| Independent / peer review | PARTIAL | colleague-review baseline exists; scientific publications in progress | Define what counts for Status-AA criterion once authoritative checklist is selected |
| Continuous quality improvement | CURRENT_EVIDENCE_PRESENT | lessons register, discrepancy register, bounded execution and control registry | Establish periodic formal review cadence if required |

## Formal mapping gate

Before this register supports a Status-AA readiness claim:

1. identify the authoritative external checklist and its exact date/version;
2. reference exact criteria rather than paraphrasing them into stronger claims;
3. bind each criterion to exact repository evidence;
4. distinguish frozen Status-A evidence from later post-Status-A evidence;
5. identify gaps and blocked evidence openly;
6. obtain independent review of the mapping;
7. bind the readiness statement to exact Git authorities.

Until then, this file remains a planning surface only.
