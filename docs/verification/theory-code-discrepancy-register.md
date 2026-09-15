# Theory-code discrepancy register

## Purpose

This register records material differences or unresolved questions between SWAP theory, formal or user documentation, corrected legacy behaviour and SWAP5 implementation.

A discrepancy is not automatically a code bug. It remains open until scientific and technical evidence supports a classification and resolution.

The governing policy is [Quality governance: Status A to Status AA](../development/quality-governance-a-aa.md).

## Status vocabulary

Use one of:

- `NOT_ASSESSED`
- `INVESTIGATING`
- `DOCUMENTATION_ERROR`
- `LEGACY_CODE_DEFECT`
- `INTENTIONAL_LEGACY_DIFFERENCE`
- `ACCEPTED_SWAP5_DIFFERENCE`
- `RESOLVED`
- `BLOCKED`

A status that asserts a cause must point to supporting evidence.

## Entry template

```text
ID:
PROCESS / COMPONENT:
THEORY OR FORMAL DESCRIPTION:
DOCUMENTED BEHAVIOUR:
CORRECTED LEGACY BEHAVIOUR:
SWAP5 BEHAVIOUR:
AFFECTED SOURCE / INTERFACE:
PHYSICAL OR NUMERICAL IMPACT:
CLASSIFICATION / STATUS:
SOURCE COMMIT:
QUALIFICATION COMMIT OR EVIDENCE:
DECISION:
NEXT ACTION:
```

## Open register

No discrepancy is created merely from suspicion. Add an entry when a concrete mismatch or unresolved interpretation has been identified and can be tied to a process, document, source location, test or observed behaviour.

| ID | Process / component | Difference | Status | Evidence / next action |
| --- | --- | --- | --- | --- |
| _none yet_ | | | | |

## Resolution rule

Closing an entry must preserve the history of what differed and why the chosen resolution was accepted. If resolution changes production physics, numerical policy, state ownership or a shared interface, the normal architecture and qualification gates still apply.
