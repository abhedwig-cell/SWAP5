# Online publication

## Status

GitHub Pages is the primary publication route for the SWAP documentation. The Markdown source, MkDocs configuration and documentation checks remain platform-independent. GitHub is therefore a deployment host, not part of the SWAP kernel or its runtime architecture.

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
                 main branch: deploy
                              |
                              v
                         GitHub Pages
```

Pull requests are built but never deployed. A push to `main` is deployed only after the same strict build has passed.

## Repository files

The publication path is defined by:

- `.github/workflows/docs.yml` for validation, build and deployment;
- `requirements-docs.txt` for the pinned top-level documentation dependency;
- `tools/docs/check_docs.py` for repository-local source checks;
- `mkdocs.yml` for site structure and rendering;
- `docs/` for the version-controlled source.

Generated `site/` output is disposable and is excluded from source control.

## One-time GitHub setup

After the source repository has been created on GitHub:

1. push the D2 files to the repository;
2. open **Settings > Pages**;
3. choose **GitHub Actions** as the Pages source;
4. ensure the default production branch is `main`;
5. run the `Documentation` workflow or push a documentation change to `main`;
6. use the deployment URL reported by the `github-pages` environment as the initial documentation URL.

A custom domain can be attached later. It should not be hard-coded into the source until the domain is actually assigned.

## CI gates

The workflow first installs the pinned documentation toolchain and then runs:

```bash
python tools/docs/check_docs.py
mkdocs build --strict --site-dir site
```

The repository check verifies navigation targets, relative Markdown links, the complete set of 30 architecture invariants and the absence of committed build output.

The MkDocs strict build remains authoritative for MkDocs configuration, theme and renderer warnings. The two checks are complementary.

## Failure policy

A documentation warning is treated as a failed build. This is deliberate. Documentation is part of the technical interface and should not be published when navigation, references or rendering are known to be inconsistent.

A failed documentation deployment does not affect SWAP numerical results or runtime execution. It blocks only publication of the affected documentation revision.

## Platform portability

The generated `site/` directory is static HTML. If the repository later moves to GitLab or an institutional host, the Markdown and MkDocs source remain unchanged. Only the deployment adapter should need replacement.

## Post-deployment acceptance check

After the first Pages deployment, verify the published site from outside the build job:

```bash
python tools/docs/verify_publication.py https://OWNER.github.io/REPOSITORY/
```

The verifier checks that the home page, target architecture, architecture invariants and publication page are all reachable and contain expected SWAP documentation markers. This catches a class of deployment errors that a successful static build alone cannot detect, such as a wrong repository path or an inaccessible Pages site.

The initial online publication is accepted only when all of the following are true:

1. the `Documentation` workflow succeeds on `main`;
2. `mkdocs build --strict` succeeds in that workflow;
3. the `github-pages` deployment job succeeds;
4. the reported Pages URL is recorded as the canonical initial documentation URL;
5. `verify_publication.py` succeeds against that URL.

A custom domain is a later deployment decision. It is not part of D2c acceptance.
