# SWAP5

SWAP5 is the modernized SWAP codebase and its technical documentation, qualification evidence, reference material and governance records.

The first colleague-review package uses a frozen Status-A scientific denominator. Ongoing development can continue on later canonical heads without silently changing that frozen review claim.

## Start here

- Practical repository entry point: [Getting started: build, run, input and output](docs/getting-started.md)
- Scientific, numerical and software review route: [SWAP5 review guide](docs/review/REVIEW_GUIDE.md)
- Current frozen Status-A scope: [Status-A current status](docs/status-a/CURRENT_STATUS.md)
- Theory-to-code-to-evidence map: [Status-A traceability](docs/status-a/TRACEABILITY.md)
- Documentation portal source: [SWAP5 technical documentation](docs/index.md)

The repository does not claim one broad stable public SWAP5 CLI/API or a wholesale replacement of all historical SWAP input/output formats unless a separately admitted authority establishes that interface. Internal qualification runners are not end-user commands by default.

## Validate the documentation locally

```bash
python -m pip install -r requirements-docs.txt
python tools/docs/check_docs.py
mkdocs build --strict
```

These are the repository documentation checks used for the review portal.

## Historical and target material

The repository intentionally retains SWAP 4.3.1 reference material, migration history and target-architecture documents. Historical or target pages are evidence of lineage and design intent; present-state claims defer to the current Status-A authority layer and capability-specific admission records.

## Licensing

The licence files originate from the SWAP 4.3.1 distribution. Repository documentation does not create a separate licensing decision from the SWAP project.
