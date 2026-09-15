# Documentation workflow

The documentation follows a docs-as-code workflow. Markdown source is versioned with the software and reviewed with the code it describes.

Documentation is also a qualification artifact. The project-wide rules for scientific traceability, Status A to Status AA maturity, discrepancy handling and evidence are defined in [Quality governance: Status A to Status AA](quality-governance-a-aa.md).

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

A corrected legacy reference is a behavioural reference, not automatically proof that the historical implementation matches the scientific theory. Material documentation shall therefore distinguish among:

- intended theory or formal model description;
- documented historical behaviour;
- observed legacy implementation behaviour;
- qualified SWAP5 behaviour;
- unresolved discrepancies.

Known differences between these layers belong in the versioned theory-code discrepancy register until they are resolved with evidence.

## Architecture changes

An important architecture change should normally include:

1. an ADR or update to an existing ADR;
2. the affected invariant numbers;
3. updated API or data-ownership documentation where relevant;
4. verification evidence or an explicit statement that qualification is still pending;
5. updated scientific or user documentation when model meaning, applicability, parameter semantics, state ownership or numerical policy changes;
6. a discrepancy-register entry when theory, documentation and implementation cannot yet be reconciled.

## Scientific traceability

For material model processes, documentation should progressively support this chain:

```text
scientific process / theory
        -> formal model description
        -> production implementation
        -> verification or qualification test
        -> versioned evidence
```

The mapping need not be one equation to one subroutine. It must, however, be sufficiently explicit that a reviewer can determine how the documented model is realized and where its behaviour is tested.

Important parameters and variables should use or contribute to the canonical registry described in the quality governance policy, including meaning, unit, owner, role, precision policy and legacy equivalence where known.

## Parallel development

Parallel development follows the [workstream coordination guide](workstreams.md). Git plus accepted versioned documentation is the source of truth. Individual chats are working contexts and may not silently redefine a shared interface for other streams.

Material pull requests should identify the workstream, exact baseline, touched components, changed interfaces, affected architecture invariants, verification state and integration dependencies. When a shared integration surface is involved, the workstream should also carry a merge contract as defined in the quality governance policy.

## Status A to Status AA

Status A is treated as an explicit intermediate model-quality milestone and Status AA as a longer-term target. Evidence required for later quality assessment should be accumulated during development rather than reconstructed retrospectively.

This does not mean that every current work unit must complete all future Status AA activities. It means that present choices should preserve traceability, reproducibility, reviewability, uncertainty evidence and model-management information needed for later maturation.

## Generated code reference

A later documentation stage can add generated Fortran API reference, for example with FORD. Generated reference should remain subordinate to hand-written architecture and physics documentation. Procedure listings explain what code exists; they do not replace design rationale.

## Online publication

GitHub Pages is the primary publication adapter selected in D2. Pull requests run the documentation gates without deploying. A successful documentation build on `main` is eligible for deployment.

See [Online publication](publication.md) for the exact workflow and the one-time repository setup.
