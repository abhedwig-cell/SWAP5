# SWAP technical documentation

This repository seed contains the docs-as-code source for the SWAP technical documentation and target modular architecture.

The documentation distinguishes between the released SWAP 4.3.1 baseline and architecture that is still under development. Architectural target documentation must not be read as a claim that the corresponding implementation already exists in SWAP 4.3.1.

## Validate locally

```bash
python -m pip install -r requirements-docs.txt
python tools/docs/check_docs.py
mkdocs build --strict
```

See `README_DOCS.md` for the documentation workflow and `D2b_REMOTE_REPOSITORY_SEED.md` for publication status.

## Licensing

The licence files are copied from the SWAP 4.3.1 distribution. D2b does not make a new licensing decision for documentation separately from the SWAP project.
