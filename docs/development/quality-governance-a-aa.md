# Quality governance: Status A to Status AA

## Purpose

SWAP5 shall be developed and qualified so that formal model-quality requirements are supported by the architecture, evidence model and development process itself. Status A is an explicit intermediate milestone. Status AA is the intended longer-term quality target.

This policy does not reopen qualified SWAP5 architecture merely to make it cleaner. The governing rule is:

```text
backport governance and evidence principles, not redesign
```

Any change to production physics, numerical policy, transactional semantics, state layout or shared interfaces remains subject to the existing architecture and qualification gates.

## 1. Status A and Status AA are development requirements

Status A is not a documentation exercise performed after implementation. SWAP5 workstreams shall preserve the evidence needed to demonstrate model description, implementation, testing, provenance, applicability, parameter and variable definitions, validation, uncertainty treatment, version management, operational ownership and user guidance.

The project should be structured so that reaching Status A does not require a later architectural rewrite to support Status AA. Status AA-related activities such as stronger uncertainty analysis, independent or peer review, reproducibility and continuous quality improvement may mature later, but their evidence must not be made impossible by current design choices.

## 2. Theory, documentation, implementation and evidence must be reconciled

A corrected legacy reference is a behavioural oracle, not automatically a scientific oracle.

For material model processes, SWAP5 shall progressively establish a traceable chain:

```text
scientific process / theory
        -> formal model description
        -> production implementation
        -> verification or qualification test
        -> versioned evidence
```

Where the theoretical documentation, historical documentation, corrected legacy code and SWAP5 implementation differ, the difference must be classified rather than silently resolved.

Allowed provisional classifications include:

- documentation error or outdated documentation;
- confirmed legacy-code defect;
- intentional historical implementation difference;
- accepted SWAP5 design or numerical-policy difference;
- unresolved discrepancy requiring investigation.

## 3. Theory-code discrepancy register

Material unresolved differences shall be recorded in a versioned discrepancy register. Each entry should identify, where known:

```text
ID
PROCESS / COMPONENT
THEORY OR FORMAL DESCRIPTION
DOCUMENTED BEHAVIOUR
LEGACY BEHAVIOUR
SWAP5 BEHAVIOUR
AFFECTED SOURCE / INTERFACE
PHYSICAL OR NUMERICAL IMPACT
CLASSIFICATION
EVIDENCE
STATUS
DECISION / NEXT ACTION
```

A discrepancy must not be converted into a production-code change merely because one source of documentation appears more plausible. Qualification evidence and scientific assessment decide the resolution.

## 4. Canonical variable and parameter registry

SWAP5 shall progressively maintain a canonical registry for important model quantities. A registry entry should contain, where applicable:

```text
canonical_name
meaning
unit
owner
role: state / parameter / forcing / result / diagnostic / exchange
shape or domain
precision / kind policy
valid range or constraints
legacy equivalent
source or scientific reference
```

The registry should support documentation, coupling contracts, model ownership, testing and future SWAP-ANIMO-WOFOST integration. A component may consume a quantity without owning its persistent state.

## 5. Legacy and remaining interface correctness

Where legacy-style Fortran interfaces remain relevant, interface correctness shall be audited as a quality activity, not only as style cleanup.

Checks should include, where applicable:

- actual versus declared type and kind;
- scalar versus array and shape consistency;
- observed read/write intent;
- unused or propagation-only arguments;
- inconsistent call sites;
- aliasing and repeated actual arguments;
- initialization assumptions;
- units and semantic meaning;
- compiler diagnostics that expose tolerated legacy constructs.

Confirmed defects follow the corrected-reference policy. Suspicious but unresolved constructs are recorded before cleanup. Argument reduction must not hide dependencies in global mutable state or oversized context objects.

## 6. Explicit precision and numerical policy

Floating-point precision must be explicit and centrally governed. SWAP5 shall avoid accidental compiler-dependent precision and shall document the canonical kinds used for persistent state, solver quantities, exchange interfaces, mass accounting and diagnostics.

A future move to single precision or mixed precision is a numerical-policy change unless proven otherwise. It requires dedicated qualification including long-horizon drift, physical regression, conservation behaviour, extreme cases, memory impact and performance benefit.

Hard conservation accounting and qualification diagnostics must not lose precision merely to reduce storage or runtime cost without explicit evidence and approval.

## 7. Parallel development by ownership, serial integration for shared semantics

The development rule is:

```text
parallel where ownership is disjoint
serial where semantics are shared
```

Parallel workstreams are preferred for tests, documentation, static analysis, scientific reconciliation, qualification tooling, benchmarks and well-isolated production components.

Shared architectural changes require controlled integration. Examples include:

- canonical state layout;
- kernel and time contracts;
- transaction semantics;
- shared exchange types;
- numerical policy;
- mass-accounting infrastructure;
- common solver or runtime interfaces.

Parallel workstreams must not create long-lived competing production truths.

## 8. Merge contract for material parallel workstreams

A material workstream that can affect a shared integration surface shall state a merge contract before substantial implementation. At minimum:

```text
WORKSTREAM
EXACT BASELINE
OWNED COMPONENTS / ALLOWED PRODUCTION SURFACE
READ-ONLY SHARED CONTRACTS
INTERFACES ALLOWED TO CHANGE
INTERFACES NOT ALLOWED TO CHANGE
DEPENDENCIES
EXPECTED INTEGRATION POINT
REQUIRED QUALIFICATION
BLOCKERS / HOLDS
```

If a workstream discovers that it must alter a shared contract outside this boundary, that change becomes an explicit integration decision rather than a silent local extension.

## 9. Workstream dependency graph and serial gates

The project shall distinguish independent parallel work from hard serial dependencies. Workstream plans should make their dependency graph explicit enough to answer:

- what can proceed from the current qualified baseline;
- what is blocked by an unqualified shared interface;
- which workstreams may run concurrently without merge debt;
- where a serial canonical integration gate is required before downstream work proceeds.

Maximizing the number of simultaneous branches is not a goal. Minimizing conflicting merge surfaces while preserving safe parallelism is.

## 10. Documentation is part of qualification

Docs-as-code remains the documentation mechanism, but documentation is also a qualification artifact.

A material change that alters documented scientific meaning, state ownership, an exchange contract, numerical policy, applicability or operational behaviour is not fully closed merely because executable tests pass. The corresponding canonical documentation must either be updated or explicitly record that documentation qualification remains open.

Generated API documentation may support this chain but does not replace scientific, architectural or user-facing explanation.

## 11. Lessons register and cross-model reuse

SWAP5 shall maintain lessons in a form that distinguishes:

```text
SWAP-specific
reusable modelling/software principle
relevant to ANIMO modernisation
relevant to SWAP-ANIMO-WOFOST coupling
candidate for backport to current SWAP5
future-only / do not backport
```

A lesson learned in another model project does not automatically justify changing qualified SWAP5 production code. Conversely, generally reusable governance, evidence and qualification improvements should be considered for backport when they do not destabilize qualified architecture.

## 12. Adoption rule for the current qualified baseline

The F-CI qualified canonical closeout at commit `7f906fcc53a4133b0e410eac7cf79fbb4eb672ab` remains an immutable provenance reference for the F-CI exit. This policy may be integrated downstream as documentation/governance without rewriting that historical qualification claim.

Any future production change motivated by this policy must identify its own source commit, qualification commit and affected gate status. Documentation adoption alone must not be reported as production qualification.
