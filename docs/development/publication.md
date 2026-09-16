# Online publication

## Status

GitHub Pages is the primary publication route for the SWAP documentation. The Markdown source, MkDocs configuration and documentation checks remain platform-independent. GitHub is therefore a deployment host, not part of the SWAP kernel or its runtime architecture.

The first colleague-review portal is not published from moving `main`. Its publication authority is the dedicated frozen review branch described in [Frozen review publication authority](../review/PUBLICATION_AUTHORITY.md).

## Publication contract

A documentation change follows this path:

```text
Markdown / configuration change
            |
            v
repository source checks
            |
            v
mkdocs build --strict
            |
       build passed?
        /         \
      no           yes
      |             |
   reject       pull request: stop
                 review-publication branch: deploy
                                           |
                                           v
                                      GitHub Pages
                                           |
                                           v
                                external site verification
```

Pull requests are built but never deployed. A push to the dedicated review-publication branch is deployed only after the same strict checks have passed. A push to `main` does not publish the first Status-A review portal.

## Frozen scientific versus documentation authority

The first review package separates two hashes deliberately:

- frozen Status-A scientific authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`;
- frozen scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`;
- documentation publication authority: the exact `GITHUB_SHA` of the successful deployment run on `publication/status-a-review-20260916`.

The documentation revision may be newer because reconciliation, explanation and publication metadata can change without changing the scientific production postimage.

## Repository files

The publication path is defined by:

- `.github/workflows/docs.yml` for validation, build and deployment;
- `docs/review/PUBLICATION_AUTHORITY.md` for the review-publication authority contract;
- `requirements-docs.txt` for the pinned top-level documentation dependency;
- `tools/docs/check_docs.py` for repository-local source checks;
- `tools/docs/verify_publication.py` for external post-deployment checks;
- `mkdocs.yml` for site structure and rendering;
- `docs/` for the version-controlled source.

Generated `site/` output is disposable and is excluded from source control.

## Publication branch

The first review publication surface is:

```text
publication/status-a-review-20260916
```

It is a deployment surface, not a feature-development branch. Scientific or application development belongs on its owning workstream and reaches a later review package only through an explicit new acceptance/review decision.

The exact deployed commit is recorded from the successful workflow run in the F-DOC20 closeout evidence.

## GitHub Pages setup

Repository Pages must use **GitHub Actions** as the Pages source. The workflow itself controls whether a built revision is eligible to deploy.

No assumption that the default repository branch is scientifically current is part of the publication contract.

A custom domain can be attached later. It should not be hard-coded into the source until the domain is actually assigned.

## CI gates

The workflow first installs the pinned documentation toolchain and then runs:

```bash
python tools/docs/check_docs.py
mkdocs build --strict --site-dir site
```

The repository check verifies navigation targets, relative Markdown links, the complete set of architecture invariants and the absence of committed build output.

The MkDocs strict build remains authoritative for MkDocs configuration, theme and renderer warnings. The two checks are complementary.

## Failure policy

A documentation warning is treated as a failed build. This is deliberate. Documentation is part of the technical interface and should not be published when navigation, references or rendering are known to be inconsistent.

A failed documentation deployment does not affect SWAP numerical results or runtime execution. It blocks only publication of the affected documentation revision.

A deployment failure must not be repaired by changing scientific claims, production semantics or the frozen scientific denominator.

## Platform portability

The generated `site/` directory is static HTML. If the repository later moves to GitLab or an institutional host, the Markdown and MkDocs source remain unchanged. Only the deployment adapter should need replacement.

## Post-deployment acceptance check

After Pages deployment, the workflow verifies the published site from a separate job:

```bash
python tools/docs/verify_publication.py https://OWNER.github.io/REPOSITORY/
```

The verifier checks the current reviewer-facing routes and their authority markers, including the home page, getting-started guidance, frozen review baseline/publication authority, Status-A current status/architecture/traceability, scientific and numerical overview pages and the admitted capability index.

This catches deployment errors that a successful static build alone cannot detect, such as a wrong repository path, stale published content or an inaccessible Pages site.

## Publication acceptance

The first online Status-A review publication is accepted only when all of the following are true:

1. the exact publication revision is on `publication/status-a-review-20260916`;
2. the `Documentation` workflow succeeds on that revision;
3. repository documentation checks pass;
4. `mkdocs build --strict` passes;
5. the `github-pages` deployment job succeeds;
6. `verify_publication.py` succeeds against the reported Pages URL;
7. F-DOC20 records the publication commit SHA, workflow run and external-verification PASS;
8. the site continues to identify the frozen scientific Status-A and production authorities.

A custom domain is a later deployment decision and is not required for F-DOC20 publication acceptance.
