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
| TCD-FROST-DIVDRA-03 | Separate infiltration within one compartment | Native DIVDRA overwrites the correctly computed infiltration-bottom thickness before its overlap formula. Original and B17 each fail 728/9216 multilevel cases at O0/O2; an actual single-level case also divides by zero. | LEGACY_CODE_DEFECT | [B20 adjudication](../audits/PPA_WU05B20_MULTILEVEL_REFERENCE_ADJUDICATION.md). Exact isolated reference candidate eliminates native failures and preserves 8293 unaffected controls plus complete 4536 B17 inputs. Independent 80/100-digit geometry qualifies all 9216 cases and resolves the historical 645 double-comparator screens without tolerance change. Canonical reference admission remains separate. |
| TCD-FROST-MULTILEVEL-TRANSFER | Low-air signed multilevel flux transfer | Near-zero aggregate surviving drainage replaces only the deepest level with qbot, retaining other signed levels. Exact cancellation can become nonzero net flux; just above 1e-6 the common multiplier amplifies and reverses large opposite proposals. Nodal/scalar closure still holds. | UNRESOLVED_SCIENTIFIC_AUTHORITY | [B20 adjudication](../audits/PPA_WU05B20_MULTILEVEL_REFERENCE_ADJUDICATION.md). Concrete test-only absolute-rate transfer proposal preserves net across 1344 changed cases, with 7872 byte-exact controls and all original B17 outputs. Owner must accept this explicit SWAP5 policy difference or bound retained legacy semantics before production implementation. |
| TCD-FSI35-HEADED-DERIVATIVE | Legacy non-M1 dynamic-top headed replay | After binding admitted RUNON, MIGMAC11 and D2 successor identities and resolving compile prerequisites, the unchanged immutable F-KT15 production surface-regimes O0 replay fails `HeadCalc: dynamic head regime omitted surface-head derivative`. Current evidence does not determine whether the fixture, provider contract or implementation is wrong. | INVESTIGATING | Diagnostic recovery [78bc8fc2](https://github.com/abhedwig-cell/SWAP5/commit/78bc8fc2c2ae34d6643c6eab3e5f943f54d91c53), baseline canonical `4fab8a28a`. Exact result and recovery are in `integration/f-ci/F-CI93_STATUS.json`, `successor_diagnostic_20261011`. Central HeadCalc/dynamic-top authority with PPA-WU03/MIGMAC owners must resolve the discrepancy and qualify unchanged Task2/surface/dispatch gates at O0/O2. No production change, tolerance relaxation or canonical F-CI93 repair is admitted. |

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
