# Status A to Status AA gap register

## Purpose

This register tracks SWAP5 model-quality maturity from current qualified evidence toward Status A and, later, Status AA.

The governing policy is [Quality governance: Status A to Status AA](quality-governance-a-aa.md).

This file is intentionally a gap register, not a claim that SWAP5 currently holds either status. Formal criterion identifiers and wording must be mapped against the then-current authoritative WUR/WOT checklist before any formal assessment or status claim is made.

## Evidence rule

For each criterion or quality domain, record:

```text
CRITERION / DOMAIN
REQUIRED OUTCOME
STATUS
EVIDENCE
SOURCE COMMIT
QUALIFICATION COMMIT
OWNER
BLOCKERS
NEXT ACTION
LAST VERIFIED
```

Recommended internal status values:

- `NOT_ASSESSED`
- `GAP`
- `PARTIAL`
- `IMPLEMENTED`
- `EVIDENCED`
- `QUALIFIED`
- `NOT_APPLICABLE` with justification

`IMPLEMENTED` is not the same as `EVIDENCED` or `QUALIFIED`.

## Initial quality domains

These rows are project planning domains. They are not a substitute for the formal external checklist.

| Domain | Current status | Evidence / gap | Next action |
| --- | --- | --- | --- |
| Scientific and conceptual model description | NOT_ASSESSED | Existing SWAP documentation exists; systematic theory-code reconciliation is not yet registered here | Inventory canonical theory and formal model sources |
| Technical implementation and architecture | PARTIAL | Architecture invariants, ADRs and canonical integration evidence exist | Map evidence to formal quality criteria |
| Verification and regression testing | PARTIAL | Extensive VQ and F-CI evidence exists | Build criterion-to-evidence map |
| Mass conservation and transaction diagnostics | PARTIAL | Qualified gates exist in current SWAP5 work | Preserve exact provenance and map to quality assessment |
| Parameters and variables | GAP | No single canonical registry is yet governed here | Establish variable/parameter registry strategy |
| Input/output and provenance | PARTIAL | Exact source provenance is strong; model-data provenance requires separate assessment | Inventory input/output provenance requirements |
| Validation | NOT_ASSESSED | Not evaluated in this register | Inventory existing validation datasets and publications |
| Sensitivity analysis | NOT_ASSESSED | Not evaluated in this register | Identify existing studies and gaps |
| Uncertainty analysis | NOT_ASSESSED | Not evaluated in this register | Separate input, parameter, numerical and structural uncertainty evidence |
| Applicability and limitations | NOT_ASSESSED | Not evaluated in this register | Consolidate documented application domain and known limits |
| Version and configuration management | PARTIAL | Git provenance and canonical branch rules exist | Map release/configuration practices to formal criteria |
| Maintenance, ownership and continuity | NOT_ASSESSED | Not evaluated in this register | Define model ownership, support and continuity evidence |
| User documentation | NOT_ASSESSED | Documentation exists but quality mapping is not yet performed | Assess against formal criteria |
| Independent review / peer review | NOT_ASSESSED | Required maturity level and existing evidence not yet mapped | Address during AA planning |
| Continuous quality improvement | PARTIAL | Workstream gates, lessons and discrepancy registers provide a basis | Define formal improvement cycle and review cadence |

## Formal mapping gate

Before this register is used for a Status A or AA readiness statement:

1. identify the authoritative current external checklist and version/date;
2. copy or reference the exact criterion identifiers without paraphrasing them into stronger claims;
3. map each criterion to repository evidence;
4. identify missing evidence explicitly;
5. independently review the mapping;
6. record the exact source and qualification commits to which the readiness statement applies.
