# Scientific-documentation authority reconciliation

## Why this page exists

SWAP5 contains substantial scientific documentation from earlier RB1/Status-A preparation work. Some of that material remains scientifically valuable, but the branches on which it was written are not automatically current-canonical authority.

The review portal therefore reuses earlier material only after classifying its role against the frozen Status-A review baseline.

## Classification

| Source | Review classification | How it is used now |
| --- | --- | --- |
| F-DOC16 physical-system / 1D-column conceptual authority | `CURRENT_REUSABLE_WITH_RECONCILIATION` | Primary source for the conceptual-system narrative. Current capability/admission claims are rebound to Status-A rather than to the old branch head. |
| F-DOC18 RB1 physical-science T0–T7 authority | `HISTORICAL_QUALIFIED_RB1_SOURCE` | Scientific/formal source for the restricted reference soil-water, ET/root and surface-evaporation formulations. It is not presented as current-canonical implementation authority. |
| F-DOC13 RB1 TIME-REFERENCE numerical/formal authority | `HISTORICAL_RESTRICTED_NUMERICAL_SOURCE` | Used to explain the bounded numerical lineage and its hard nonclaims. It is not generalized into a universal nonlinear-error or application-accuracy claim. |
| F-DOC17 post-closure Status-A reconciliation | `HISTORICAL_STATUS_ASSESSMENT_SUPERSEDED_BY_LATER_STATUS_A_ADMISSION` | Useful evidence of how earlier documentation branches were classified. Its statement that formal Status-A was not yet justified is historical and is superseded by the later admitted Status-A authority. |
| Current `docs/status-a/*` | `CURRENT_REVIEW_AUTHORITY` | Controls current Status-A scope, architecture and theory-code-evidence navigation for the frozen review denominator. |
| Current capability qualification/admission records | `CURRENT_OR_IMMUTABLE_CAPABILITY_AUTHORITY` | Controls exact implementation/evidence claims at the capability level. |

## Important reconciliation rule

An older scientific document can remain correct about a physical concept while being obsolete about repository status.

For example, the one-dimensional column abstraction and Darcy–Buckingham/Richards scientific lineage do not become false because later SWAP5 architecture was admitted. But an older statement such as “formal Status-A is not yet justified” cannot be carried forward after the later Status-A release-readiness authority was admitted.

The review portal therefore separates:

- **scientific content validity**;
- **implementation binding**;
- **qualification/admission status**;
- **current repository authority**.

## No history rewrite

Historical documents are not rewritten to pretend they knew later results. They remain evidence of what was established at that point in the program.

The curated review pages are new current-facing documents that cite/reconcile those authorities and bind their scientific content to the frozen Status-A denominator where justified.

## Controlling current references

For current claims use:

- [Frozen review baseline](REVIEW_BASELINE.md)
- [Current Status-A scope](../status-a/CURRENT_STATUS.md)
- [Current Status-A architecture](../status-a/CURRENT_ARCHITECTURE.md)
- [Theory, code and evidence traceability](../status-a/TRACEABILITY.md)
- capability-specific qualification/admission and permanent-preservation evidence.

## Nonclaim

This reconciliation does not claim that all historical F-DOC material has already been incorporated into the review portal. F-DOC20 deliberately curates the scientific and numerical material needed for the frozen colleague review and leaves unsupported, future, duplicated or obsolete material outside the primary navigation.
