# SWAP5 agent guide

This file is a repository entry point for coding and research agents. It is navigational. It does not replace architecture decisions, qualified evidence, work-unit status records, or accepted integration contracts.

## Source of truth

Use repository state as authority. Chat history, local scratch notes, generated summaries, and remembered branch state are working context only.

When starting material work:

1. Read the exact target branch and HEAD commit.
2. Read the relevant accepted documentation and work-unit status records.
3. Identify the owning workstream and interfaces touched.
4. State which architecture invariants are affected.
5. Distinguish implemented, persisted, tested, and qualified state.

If repository state and chat context disagree, repository state wins.

## Read first

For most work, start here:

- `docs/development/knowledge-map.md` - task-oriented map of repository authority and evidence.
- `docs/architecture/invariants.md` - normative target architecture invariants.
- `docs/development/workstreams.md` - workstream ownership, integration boundaries, and coordination rules.
- `docs/development/workstream-execution-protocol.md` - checkpoint, recovery, and qualification discipline.
- `docs/development/documentation.md` - documentation status labels and docs-as-code rules.
- `docs/verification/principles.md` - verification and reference policy.
- `docs/decisions/` - accepted architecture decisions and rationale.

Then read the work-unit-specific status, integration, qualification, or evidence files for the change being made.

## Hard rules

- Do not invent current state from filenames, chat summaries, or branch names. Re-read the repository.
- Do not treat a target architecture document as proof that implementation exists.
- Do not silently change a shared interface. Record the design decision or interface contract first when required.
- Do not weaken mass conservation, transactional state semantics, restart semantics, or accepted boundary contracts to make a test pass.
- Rejected trials must not modify committed physical state.
- Keep physical options separate from numerical execution policy.
- Keep production Full Richards available as the reference production path unless an accepted authority explicitly changes that status.
- Alternative or research solvers must remain behind explicit compatibility contracts. They must not acquire hidden dependencies on production solver internals.
- Verification evidence can qualify a claim only for the scope actually tested.
- Performance evidence does not establish physical equivalence.
- Preserve legacy behaviour only when the accepted reference policy says it is part of the qualified baseline. Confirmed legacy defects are handled through the reference qualification process.

## Work-unit discipline

For a material work unit, maintain a recoverable Git state before expensive or timeout-sensitive work. Follow `docs/development/workstream-execution-protocol.md`.

A useful handoff identifies at least:

```text
WORKSTREAM
WORK UNIT
BASELINE
SCOPE
FILES / COMPONENTS TOUCHED
INTERFACES CHANGED
INVARIANTS AFFECTED
IMPLEMENTATION STATUS
TEST STATUS
QUALIFICATION STATUS
DEPENDENCIES / BLOCKERS
NEXT SAFE STEP
RECOVERY POINT
```

Do not report `tested` or `qualified` unless the named gate actually completed against the persisted postimage.

## Change strategy

Prefer the smallest change that satisfies the accepted contract.

Before editing code or contracts:

1. Locate the owning authority.
2. Search for dependent interfaces and tests.
3. Check current canonical integration state.
4. Decide whether the change is implementation, documentation, verification, or a design decision.
5. Preserve existing qualified behaviour unless the work unit explicitly changes it.

When several authorities appear relevant, use `docs/development/knowledge-map.md` to determine what each document can and cannot establish.

## Validation

Run the narrowest relevant checks first, then the declared broader gates.

Documentation changes should follow `docs/development/documentation.md`, including:

```bash
python -m pip install -r requirements-docs.txt
python tools/docs/check_docs.py
mkdocs build --strict
```

For code or numerical work, use the work-unit-specific verification and qualification gates. Do not substitute an unrelated green CI result for the required evidence.

## Documentation language

Use these status labels consistently:

- **Baseline** - verified behaviour in a named reference version.
- **Target architecture** - accepted design, not necessarily implemented.
- **Proposed** - not yet accepted.
- **Qualified** - supported by named verification evidence.

Keep claims narrow enough that a future agent can trace each one to code, a contract, a decision, or evidence.
