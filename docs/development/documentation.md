# Documentation workflow

The documentation follows a docs-as-code workflow. Markdown source is versioned with the software and reviewed with the code it describes.

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

## Architecture changes

An important architecture change should normally include:

1. an ADR or update to an existing ADR;
2. the affected invariant numbers;
3. updated API or data-ownership documentation where relevant;
4. verification evidence or an explicit statement that qualification is still pending.

## Parallel development

Parallel development follows the [workstream coordination guide](workstreams.md). Git plus accepted versioned documentation is the source of truth. Individual chats are working contexts and may not silently redefine a shared interface for other streams.

Material pull requests should identify the workstream, exact baseline, touched components, changed interfaces, affected architecture invariants, verification state and integration dependencies. The repository pull-request template encodes this handoff format.

## Generated code reference

A later documentation stage can add generated Fortran API reference, for example with FORD. Generated reference should remain subordinate to hand-written architecture and physics documentation. Procedure listings explain what code exists; they do not replace design rationale.

## Online publication

GitHub Pages is the primary publication adapter selected in D2. Pull requests run the documentation gates without deploying. A successful documentation build on `main` is eligible for deployment.

See [Online publication](publication.md) for the exact workflow and the one-time repository setup.
