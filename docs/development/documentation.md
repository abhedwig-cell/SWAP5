# Documentation workflow

The documentation follows a docs-as-code workflow. Markdown source is versioned with the software and reviewed with the code it describes.

Documentation is also part of the quality evidence chain. Current project-wide rules for Status-A preservation, Status-AA planning, theory-documentation-code-evidence reconciliation, discrepancy handling and shared-authority integration are defined in [Quality governance after Status A](quality-governance-a-aa.md).

## Local checks

Install the documentation dependency in a Python environment:

```bash
python -m pip install -r requirements-docs.txt
```

Run the repository-local source checks:

```bash
python tools/docs/check_docs.py
```

Run a local preview:

```bash
mkdocs serve
```

Run the strict build used by continuous integration:

```bash
mkdocs build --strict
```

`--strict` turns MkDocs warnings into build failures. The repository check separately verifies navigation targets, relative Markdown links and the complete architecture-invariant set.

## Writing rules

Technical pages should distinguish clearly between facts, design decisions and open proposals.

Use these labels consistently:

- **Baseline** for behaviour verified in SWAP 4.3.1 or another named version;
- **Target architecture** for accepted design that is not necessarily implemented yet;
- **Proposed** for ideas that have not been accepted;
- **Qualified** for numerical behaviour supported by named verification evidence.

Do not document an optimization as physically equivalent unless the qualification evidence supports that statement.

For material scientific or numerical claims, distinguish intended theory/formal description, historical or corrected-reference behaviour, current SWAP5 implementation, executable evidence and canonical admission. When those layers disagree, record the discrepancy rather than resolving it silently in prose.

### Completeness and authority rule

Missing documentation is not left unwritten merely because the original design record was incomplete. Apply this rule:

1. if the missing explanation can be reconstructed from accepted theory, production code and qualified evidence, write and version the documentation and link it to those authorities;
2. if the underlying scientific, numerical or interface authority is itself not established, record the missing authority as a bounded gap and do not invent a definitive statement;
3. do not promote an internal test harness, historical note or proposal into a supported public contract merely to make the documentation look complete;
4. when later evidence supersedes historical wording, retain the historical record where useful but make the current authority and scope explicit.

This is the repository form of the F-DOC20 rule: **reconstructable means document it; unproven means record the gap**.

## Architecture changes

An important architecture change should normally include:

1. an ADR or update to an existing ADR;
2. the affected invariant numbers;
3. updated API or data-ownership documentation where relevant;
4. verification evidence or an explicit statement that qualification is still pending;
5. updated scientific or user documentation when model meaning, applicability, parameter semantics, state ownership or numerical policy changes;
6. a discrepancy-register entry when theory, documentation, implementation and evidence cannot yet be reconciled.

## Parallel development

Parallel development follows the [workstream coordination guide](workstreams.md). Git plus accepted versioned documentation is the source of truth. Individual chats are working contexts and may not silently redefine a shared interface for other streams.

Material pull requests should identify the workstream, exact baseline, touched components, changed interfaces, affected architecture invariants, verification state and integration dependencies. The repository pull-request template encodes this handoff format.

## Generated code reference

A later documentation stage can add generated Fortran API reference, for example with FORD. Generated reference should remain subordinate to hand-written architecture and physics documentation. Procedure listings explain what code exists; they do not replace design rationale.

## Online publication

GitHub Pages is the publication adapter for the first frozen Status-A colleague-review portal. Pull requests run the documentation gates without deploying. The first review portal is deployed only from the dedicated publication surface `publication/status-a-review-20260916`; moving `main` is not the review publication authority.

See [Online publication](publication.md) and [Frozen review publication authority](../review/PUBLICATION_AUTHORITY.md) for the exact workflow, authority split and acceptance conditions.
