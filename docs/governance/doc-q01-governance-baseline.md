# DOC-Q01 canonical documentation governance baseline

## Scope and authority

DOC-Q01 governs documentation inventory, provenance, status and quality. It does not alter production source, physics, solver behaviour, transaction semantics, state layout, runtime, numerical or precision policy, corrected-reference content, or existing qualification decisions.

The production baseline for this assessment is `integration/f-ci-canonical` at `7f906fcc53a4133b0e410eac7cf79fbb4eb672ab`. The documentation-governance input is `governance/quality-backport-20260908` at `a6b991b4702e061accd1b16f9450f99e18aba032`. Downstream F-KT, F-SI, F-MR, F-MQ and F-VQ artifacts may be cited only with their exact source and qualification provenance. Their existence does not silently move the canonical baseline.

The corrected legacy reference is B1.10. It is a qualified behavioural oracle for its admitted scope, not automatically a scientific oracle.

## State models

Documentation moves through the following publication states:

`DRAFT -> DEVELOPMENT -> REVIEWED -> RECONCILED -> PUBLISHED_CANONICAL`

`SUPERSEDED` and `ARCHIVED` are terminal retention states. A document can be visible online while still not being `PUBLISHED_CANONICAL`. Canonical publication requires an exact release or development baseline, review owner, reconciliation record and controlled publication route.

Quality is assessed independently:

| Quality status | Minimum evidence |
| --- | --- |
| `NOT_ASSESSED` | No adequate assessment record exists. |
| `DOCUMENTED` | Scope and claims are explicit, but implementation agreement is not established. |
| `IMPLEMENTATION_TRACED` | Relevant implementation paths and exact source commit are identified. |
| `TEST_EVIDENCED` | Applicable tests or qualification records are linked with exact provenance. |
| `QUALIFIED` | Theory, formal description, documented behaviour, implementation and evidence have been reconciled under an approved quality contract; open material discrepancies are absent or explicitly bounded. |

No status is inferred from a later status in the other model. In particular, published does not mean qualified, and qualified content is not automatically the current published version.

## Reconciliation protocol

For each material claim, the reviewer records the trace:

1. scientific theory or an explicit `NOT_APPLICABLE`;
2. formal model description;
3. documented behaviour;
4. legacy implementation and exact revision where relevant;
5. SWAP5 implementation and exact source commit;
6. test or qualification evidence and exact qualification commit.

Missing links are `UNKNOWN` or `NOT_ASSESSED`; they are never reconstructed from numerical agreement alone. A conflict is entered in the theory-code discrepancy register as one of: `documentation error`, `outdated documentation`, `confirmed legacy defect`, `intentional historical difference`, `accepted SWAP5 difference`, or `unresolved discrepancy`. Until ownership and disposition are evidenced, affected claims remain fail-closed.

## Change and release contract

Every model or production-contract change must identify affected registry entries. A green code test suite does not close a change while canonical documentation still describes old semantics. The owning workstream supplies source and test provenance; a documentation owner performs reconciliation. Shared scientific meaning is updated serially after the responsible scientific or production owner resolves it.

Future documentation sets use immutable release identifiers such as `5.0` and `5.1`, plus a mutable `development` set. A release set pins source commit, documentation commit, corrected-reference version, qualification baseline and build dependencies. Published release content is immutable. Corrections create a documented patch version or erratum; development content cannot overwrite it. DOC-Q01 defines this contract but does not introduce a multi-version deployment.

The controlled route remains `docs/` and `mkdocs.yml`, source checks, `mkdocs build --strict`, pull-request review, merge to `main`, GitHub Pages deployment and live-site verification. Pull requests and successful branch builds are not canonical publication events.

## Registry maintenance

`docs/governance/documentation-registry.json` inventories every file under `docs/` plus `mkdocs.yml`, the documentation dependency lock, workflow and verification scripts. Regenerate and validate it with:

```console
python tools/docs/documentation_registry.py --write
python tools/docs/documentation_registry.py
```

The registry defaults existing content to `NOT_ASSESSED` unless DOC-Q01 has direct evidence for a stronger claim. `online_navigation_candidate` means only that the current MkDocs configuration includes the page.
