# F-PE-ELASTIC43 — CRS dependency governance audit preregistration

Date: 2026-09-29

Status: PREREGISTERED_BEFORE_AUDIT_RESULT

Baseline:
`integration/f-ci-canonical@c3393aabbc82ee15512250c54464891c84c3d414`

Parent authority:
- `F-PE-ELASTIC38_CRS_CAPABILITY_AUDIT_RESULT.md`;
- `F-PE-ELASTIC39_PROJ_CLI_AUDIT_RESULT.md`;
- `F-PE-ELASTIC40_GDAL_CLI_AUDIT_RESULT.md`;
- `F-PE-ELASTIC41_CLOSURE.md`.

## Purpose

Determine whether SWAP5 currently has an admitted repository-level mechanism for
adding a new Python/system dependency solely to support geographic-coordinate ->
EPSG:28992 preprocessing.

This work unit is governance/repository audit only.

It does not add a dependency, install a package or implement CRS transformation.

## Audit questions

A1. Is there an existing repository-wide Python dependency manifest used for
production/preprocessing tooling?

A2. Do admitted workflows already install arbitrary Python packages with
`pip`?

A3. Do admitted workflows already install system packages with `apt` or an
equivalent package manager?

A4. Is there an admitted application/preprocessing dependency policy that would
authorize adding `pyproj`, PROJ or GDAL without a separate governance change?

A5. Can the CRS blocker therefore be resolved within the current dependency
contract, or does it require an explicit dependency/governance decision?

## Evidence scope

Inspect:
- repository root dependency/packaging manifests;
- GitHub workflow package-install patterns;
- development/governance authority in `AGENTS.md` and current architecture docs;
- the negative capability evidence from ELASTIC38/39/40.

Do not infer authority from documentation-only requirements or unrelated local
developer environments.

## Decision rule

Classify one of:

- `DEPENDENCY_ROUTE_ALREADY_ADMITTED` only if an existing repository authority
  clearly covers adding the required CRS dependency;

- `EXPLICIT_DEPENDENCY_GOVERNANCE_REQUIRED` if no such authority exists;

- `INCONCLUSIVE` only if repository evidence is genuinely contradictory.

No production code change is permitted in ELASTIC43.
