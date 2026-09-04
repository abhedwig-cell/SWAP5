# D2c remote publication acceptance

**Date:** 2026-09-04

## Goal

Complete the first real GitHub Pages publication of the SWAP technical documentation and verify the deployed site end to end.

## Current status

`REMOTE_BUILD_VERIFIED_PAGES_ENABLEMENT_REQUIRED`

The repository `abhedwig-cell/SWAP5` is connected and writable. The D2 documentation source, validation scripts and GitHub Actions workflow are present on `main`.

Verified on GitHub Actions:

- documentation dependencies install successfully;
- `python tools/docs/check_docs.py` succeeds;
- `mkdocs build --strict --site-dir site` succeeds.

The current workflow stops at `actions/configure-pages` because GitHub Pages has not yet been enabled for the repository. This is a repository setting, not a documentation or MkDocs failure.

## Remaining acceptance steps

1. Enable GitHub Pages for `SWAP5` with **Build and deployment > Source = GitHub Actions**.
2. Re-run the `Documentation` workflow or trigger a documentation commit.
3. Confirm that the `Validate and build` job succeeds completely.
4. Confirm that the `Deploy GitHub Pages` job succeeds.
5. Record the deployment URL reported by the `github-pages` environment.
6. Run `python tools/docs/verify_publication.py <deployment-url>` against the live site.

D2c becomes `PUBLISHED_VERIFIED` only after all six steps are complete.
