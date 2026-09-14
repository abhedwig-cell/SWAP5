# Capability-flow development policy

Status: active prospective development policy for new SWAP5 work started after 2026-09-14.

This policy changes delivery granularity and coordination. It does not relax reference qualification, hard mass-balance gates, transaction invariants, scientific review, or production admission requirements.

## Default unit of work

The default planning unit is a capability, not every atomic correction, test, evidence packet, checkpoint, or review phase.

A capability may contain multiple small, revertible commits. Atomicity remains required at commit and scientific-decision level. A separate branch or qualification cycle is not required for every atomic change.

Preferred flow:

`CAPABILITY -> pin baseline/contracts once -> atomic commits -> integrated falsification -> qualification at capability boundary -> integration`

## New branch gate

Open a new authoritative branch only when at least one of the following is true:

1. a scientific, numerical, persistent-state, restart, API, coupling, or canonical architecture contract changes;
2. another active capability owns the same semantics and isolation is needed to avoid concurrent redesign;
3. failure or reversal must remain independently pin-able;
4. an existing qualification/admission route explicitly requires a separate decision surface;
5. the work is deliberately isolated research, preservation, verification, or measurement with a declared non-production role.

Otherwise continue as tasks and atomic commits inside the current capability branch.

Finding a new uncertainty is not, by itself, a reason to open another branch.

## No process-only branches

Do not create separate branches only for `final`, `review`, `copy`, `shadow`, `temp`, `staging`, `freeze`, `package`, `ci`, `artifacts`, `checkpoint`, or equivalent process phases.

Use immutable Git commits for authoring, qualification, review, and checkpoint pins. A second branch requires one of the branch-gate conditions above.

Historical branches remain valid evidence and are not rewritten solely to fit this policy.

## Evidence inheritance

Immutable qualified evidence is reused until one of its dependencies changes. Do not rerun a baseline, fixture, oracle, contract proof, or qualification merely to recreate ceremony.

Evidence is invalidated only when a relevant dependency changes, such as source semantics, state ownership, numerical policy, interface contract, fixture, oracle, expected-difference definition, or interpretation boundary. Rerun the affected slice only; inherit unaffected evidence.

Evidence may never be reused outside its qualified scope or promoted to a stronger evidence class.

## Risk-weighted process

| Class | Typical work | Default process |
| --- | --- | --- |
| R0 | docs, metadata, diagnostics with no semantic effect | checks + commit |
| R1 | semantics-preserving refactor, harness, tooling | targeted tests + lightweight review |
| R2 | state, IO, API, restart, coupling, lifecycle contract | targeted qualification at capability boundary |
| R3 | physics, conservation, numerical semantics, solver policy, production composition | full applicable qualification and adversarial review |

Observed semantic impact overrides the declared class.

## Work-in-progress limit

At most three production-relevant capability streams are active at one time.

A branch counts as active only while substantive authoring, qualification, or integration work is being performed. Old branches do not count merely because they exist.

Independent VQ, MP, documentation, preservation, or research streams may operate outside this limit only when they have disjoint semantic ownership, do not require a moving production interface, and cannot silently become a production dependency.

When the limit is reached, finish, pause, or integrate an active production capability before starting another.

## Capability-level qualification

Within one capability:

- keep commits small and revertible;
- run cheap tests continuously;
- persist important decisions at the point they are made;
- accumulate one evidence package;
- perform integrated falsification and the applicable qualification at the next real contract or admission boundary.

Do not run the full governance and qualification cycle for every internal step unless that step itself crosses a scientific or architectural contract boundary.

## Governance and documentation stop rule

Create a new cross-cutting governance or coordination artifact only when it removes a concrete ambiguity, defines a reusable contract, resolves a blocking ownership collision, creates a required auditable decision surface, or demonstrably prevents repeated future work.

If a new document would only restate an existing rule or require another document to explain it, amend or reference the current authority instead.

## Progress accounting

Track progress by four dimensions:

1. capability implementation;
2. qualification;
3. canonical integration;
4. preservation and traceability.

Branch count, document count, review packets, and intermediate workunit count are not product-progress metrics by themselves.

## Minimal process telemetry

For each completed capability record:

- substantive implementation/science commits;
- governance/evidence-only commits;
- evidence reruns caused by actual invalidation;
- reopened decisions;
- other active branches that required reconciliation before completion.

Use these values to detect process overhead. Do not create separate telemetry workstreams.

## Relationship to existing SWAP5 rules

This policy does not weaken the B0/B1/B2 reference model, transaction rollback/commit guarantees, exact accounting requirements, scientific qualification, or explicit production authorization boundaries. Where a stricter scientific or safety gate applies, that gate controls.

For coordination purposes this document supersedes the previous default that four implementation streams plus additional verification/performance streams are routinely manageable. The new default is three production-relevant capabilities, with only genuinely independent verification, preservation, measurement, or research work outside that limit.
