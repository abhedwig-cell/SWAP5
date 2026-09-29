# F-PE-ELASTIC38 — CRS transformation capability audit result

Date: 2026-09-29

Status: ROUTE_FALSIFIED

Branch:
`research/f-pe-elastic38-crs-capability-audit`

Audited postimage:
`6ade2c8444b35f9350de9a59d198cdd677ced509`

Workflow run:
`36592536440`

Job:
`109489035508`

Conclusion:
FAILURE.

## Result

The preregistered primary route requires the standard SWAP5 GitHub runner to
provide `pyproj` without adding a repository dependency.

That requirement is not met.

Observed failure:

`ModuleNotFoundError: No module named 'pyproj'`.

Therefore the preregistered production-readiness condition fails before any CRS
transformation claim can be evaluated.

## Decision

Classification:

`ROUTE_FALSIFIED_PYPROJ_NOT_AVAILABLE_ON_STANDARD_RUNNER`.

ELASTIC38 does not admit:
- a production CRS adapter;
- a new Python dependency;
- implicit package installation;
- any WGS84 -> EPSG:28992 transformation.

## Preserved next question

A separate work unit may evaluate whether already-installed PROJ command-line
tools provide a defensible offline transformation route without adding a
repository dependency.

That alternative must be preregistered separately and may not reinterpret this
negative result as a pass.
