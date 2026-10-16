# F-PE-ELASTIC43 — CRS dependency governance audit result

Date: 2026-09-29

Status: GOVERNANCE_BLOCKER_CONFIRMED

Baseline:
`integration/f-ci-canonical@69f529bfcbb77f0e4b583f892aa3d24fea105128`

Audited branch:
`research/f-pe-elastic43-crs-dependency-governance@ee348acab3d66ae92d6c6b80d7313d3212026065`

## Evidence

Repository root:
- no production/preprocessing Python dependency manifest such as
  `pyproject.toml`, `requirements.txt`, `environment.yml` or equivalent;
- the only root requirements file is `requirements-docs.txt`, containing only
  `mkdocs-material==9.7.7` and explicitly serving documentation validation.

Repository workflow/source search:
- no admitted workflow pattern was found that installs arbitrary runtime or
  preprocessing Python packages with `pip`;
- no admitted workflow pattern was found that installs system packages with
  `apt` or an equivalent package manager.

Repository governance:
- `AGENTS.md` requires explicit ownership and acceptance authority before
  changing shared interfaces/dependencies;
- the workstream protocol requires a real dependency/governance blocker to be
  persisted rather than silently widening scope.

Capability evidence:
- ELASTIC38 falsified the dependency-free `pyproj` route;
- ELASTIC39 falsified the dependency-free `cs2cs` route;
- ELASTIC40 falsified the dependency-free GDAL/`gdaltransform` route.

## Decision

Classification:

`EXPLICIT_DEPENDENCY_GOVERNANCE_REQUIRED`.

There is no existing admitted repository mechanism that authorizes adding
`pyproj`, PROJ or GDAL as a new preprocessing dependency merely because CRS
support is desired.

Therefore ELASTIC43 does not:
- add a dependency;
- install a package in CI;
- modify production/preprocessing source;
- claim geographic-coordinate -> EPSG:28992 support.

## Consequence

The ELAS chain is operationally complete for callers that already provide
EPSG:28992 RD coordinates.

Geographic-coordinate input remains blocked until an explicit repository
dependency decision is made. That decision must separately define at least:
- chosen CRS implementation/dependency;
- version pinning;
- installation/packaging ownership;
- reproducibility/offline expectations;
- CI qualification;
- source-data/grid requirements;
- failure behavior when the dependency is absent.

This blocker is governance/dependency scope, not an unresolved ELAS physics or
BOFEK/BRO profile-semantics problem.
