# F-DOC35 authority matrix — documentation entry-point reconciliation

## Decision surface

F-DOC35 reconciles the repository's principal documentation entry points with documentation that is already present and admitted on current canonical.

It does **not** add a new application interface, input grammar, output schema, scientific capability, numerical method or production route.

## Controlling authorities

| Authority | Exact identity | Permitted use |
|---|---|---|
| Live canonical at branch start | `62dfb5a52f665e490830dfb320167786cf67f63e` | documentation integration base |
| Frozen Status-A authority | `992a5c657bfe10a10100f92e0cb77c4825ae65b6` | frozen review denominator |
| Frozen scientific production baseline | `50346642bd565f79134ea17d5462e544b354998c` | scientific production denominator |
| F-DOC20 close record | `integration/f-doc/F-DOC20_STATUS.json` | proves that the practical entry slice, including build/run/input/output guidance, was already qualified/admitted |
| Current getting-started page | `docs/getting-started.md` on branch start | current bounded practical repository entry point |
| Current documentation landing page | `docs/index.md` on branch start | current site-level orientation |
| Current review guide | `docs/review/REVIEW_GUIDE.md` on branch start | role-specific review navigation |
| F-DOC34 reference-preservation reference | current canonical documentation | current preservation/navigation discipline; no production claims added here |

## Reconciled findings

1. `docs/getting-started.md` already provides the bounded build/run/input/output entry point qualified under F-DOC20.
2. `docs/review/REVIEW_GUIDE.md` still says that a dedicated build/run/input/output user section is future work. That statement is stale.
3. `README.md` still describes the repository as a documentation/target-architecture seed and points to `README_DOCS.md`, which is not present at the repository root on the branch-start canonical.
4. `docs/index.md` still contains wording that scientific and numerical narratives are "being expanded in F-DOC20", although those sections have subsequently been expanded through later admitted F-DOC workunits.

## Permitted changes

- route repository users to `docs/getting-started.md`, the review guide, and current Status-A documentation;
- remove stale "future F-DOC20" wording where the referenced documentation now exists;
- replace obsolete repository-seed/current-status wording in the root README;
- remove references to nonexistent `README_DOCS.md`;
- keep the broad public CLI/API and wholesale legacy-I/O modernization explicitly outside the frozen Status-A claim.

## Forbidden changes

- no `src/**`, `reference/**`, `tests/**` or `testbank/**` mutation;
- no new application command or public interface invented from qualification runners;
- no expansion of the frozen scientific denominator;
- no Ross/RossFast, EB or post-Status-A capability promotion;
- no change to scientific, numerical or runtime semantics.

## Documentation verdict

`ENTRYPOINT_RECONCILIATION_SUPPORTED`
