# Quality governance after Status A: route toward Status AA

## Purpose

SWAP5 has an admitted frozen Status-A review baseline. The current governance task is therefore not to "reach Status A" again, but to preserve that historical authority while continuing post-Status-A development in a way that can support later Status-AA assessment.

The frozen Status-A authorities remain:

- Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`;
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`;
- first colleague-review denominator: the frozen Status-A package documented under `docs/status-a/**` and `docs/review/**`.

Later canonical development does not retroactively rewrite that frozen denominator.

The governing rule is:

```text
preserve historical authority
reconcile current authority explicitly
improve governance without silently redesigning qualified science
```

This policy does not itself authorize production-code, solver, coupling, timestep, tolerance, state-layout or physics changes.

## 1. Authority layers must remain distinct

Every material claim should identify which authority layer supports it:

1. scientific or theoretical authority;
2. formal or user documentation;
3. corrected legacy/reference implementation;
4. current SWAP5 production implementation;
5. executable verification or qualification evidence;
6. canonical admission or closure authority;
7. later preservation or supersession evidence.

A later authority may supersede an earlier status interpretation without rewriting the historical record that produced it.

A corrected legacy reference is a behavioural oracle inside its qualified scope. It is not automatically a scientific oracle.

## 2. Theory, documentation, code and evidence reconciliation

For material scientific or numerical behaviour, workstreams should maintain a traceable chain:

```text
scientific process / theory
        -> formal model description
        -> implementation
        -> verification / qualification
        -> canonical decision
        -> preservation / supersession
```

When those layers disagree, the difference must be classified instead of silently choosing one source.

Permitted provisional classifications include:

- `DOCUMENTATION_ERROR`;
- `LEGACY_CODE_DEFECT`;
- `INTENTIONAL_LEGACY_DIFFERENCE`;
- `ACCEPTED_SWAP5_DIFFERENCE`;
- `AUTHORITY_BINDING_DEFECT`;
- `IMPLEMENTATION_DEFECT`;
- `UNRESOLVED_SCIENTIFIC_AUTHORITY`;
- `BLOCKED_EXTERNAL_AUTHORITY`;
- `INVESTIGATING`.

A classification that asserts cause requires supporting evidence.

## 3. Discrepancy register

Material unresolved theory-documentation-code-evidence differences belong in the versioned [theory-code discrepancy register](../verification/theory-code-discrepancy-register.md).

A discrepancy is not automatically a production bug. Resolution can be:

- documentation correction;
- authority reinterpretation;
- source repair;
- accepted bounded difference;
- external-source blocker;
- scientific decision;
- supersession by a later canonical authority.

Production changes remain subject to the normal owning workstream and canonical admission process.

## 4. Canonical quantity and precision policy

Important model quantities should progressively have explicit meaning, unit, owner, role, shape/domain, precision policy, constraints and legacy/scientific reference where applicable.

Precision is numerical policy. A move to lower or mixed precision is not a transparent cleanup unless dedicated evidence establishes that it is so for the claimed scope.

Hard conservation accounting and qualification diagnostics must not lose precision merely to obtain performance or storage gains without explicit qualification.

## 5. Parallel development rule

The project-wide execution rule is:

```text
parallel where ownership is disjoint
serial where semantics are shared
```

Parallel development is encouraged for isolated implementation, testing, evidence generation, documentation, research experiments and tooling.

A workstream must stop local semantic expansion and return to the appropriate shared integration authority when it needs to alter, for example:

- committed/candidate state ownership;
- common transaction semantics;
- shared exchange or coupling contracts;
- application ownership;
- mass-accounting ownership;
- common solver/runtime interfaces;
- numerical policy;
- cross-workstream publication authority.

The current central routing surface is `integration/control/SWAP5_WORKSTREAM_REGISTRY.json`.

## 6. Merge contract for shared surfaces

A material workstream that can affect shared semantics should identify before admission:

```text
WORKSTREAM
EXACT BASELINE
OWNED SURFACE
READ-ONLY AUTHORITIES
INTERFACES ALLOWED TO CHANGE
INTERFACES HELD FIXED
DEPENDENCY SURFACE
REQUIRED QUALIFICATION
CROSS-WORKSTREAM CONSEQUENCES
CANONICAL ADMISSION OWNER
```

A branch or green focused test does not create project-wide authority by itself.

## 7. Documentation is qualification evidence

Documentation is part of the qualified model artifact when a change alters scientific meaning, state ownership, applicability, numerical policy, coupling/exchange contracts or operational behaviour.

Executable tests can establish behaviour while documentation remains incomplete. In that case the work unit must record the documentation gap rather than declaring complete closure.

Generated API listings are subordinate to scientific, architectural and user-facing explanation.

## 8. Evidence inheritance and requalification

Immutable evidence remains usable while the dependencies relevant to the evidence remain unchanged.

When a dependency changes:

1. identify the affected evidence and preservation contracts;
2. requalify only the affected surface and required transitive dependencies;
3. record the new postimage and result;
4. do not reopen unrelated capabilities merely because canonical moved.

Conversely, an old exact-blob preservation failure after an intentional successor does not by itself prove a scientific regression. It is a signal to reconcile the preservation authority.

## 9. Status-AA planning boundary

This repository does not claim Status AA merely because the governance needed for it exists.

Before any formal Status-AA readiness statement:

1. identify the authoritative external checklist and version/date;
2. map exact criterion identifiers to repository evidence;
3. identify missing evidence explicitly;
4. separate implemented, evidenced, qualified and independently reviewed states;
5. independently review the mapping;
6. bind the readiness statement to exact repository authorities.

The [Status-A to Status-AA gap register](status-a-aa-gap-register.md) is therefore an internal planning surface, not the external assessment itself.

## 10. Lessons and continuous improvement

Reusable lessons should be persisted in the [SWAP5 lessons register](lessons-register.md), with an explicit distinction between:

- SWAP-specific action;
- generally reusable modelling/software principle;
- cross-model relevance;
- safe governance backport;
- future-only idea.

A lesson does not authorize a production mutation.

## 11. Relation to PROJECT-CONTROL

The PROJECT-CONTROL registry is the routing layer for live workstream ownership and admission. This quality policy supplies the governance rules used by that routing layer.

When the two appear inconsistent, reconcile the registry against current canonical authority and this policy rather than allowing individual chats or branches to create a second project truth.

## Historical provenance

This document is a current-canonical recomposition of the useful governance principles originally proposed in PR #72. PR #72 was based on an earlier pre-Status-A context and must not be merged as-is. Its historical F-CI18 provenance remains valid for the claims made at that time.
