# F-PE-ELASTIC39 — PROJ CLI CRS capability audit result

Date: 2026-09-29

Status: ROUTE_FALSIFIED

Branch:
`research/f-pe-elastic39-proj-cli-audit`

Audited postimage:
`c0d93c36a78e283abbed654a15646bff5a44caf3`

Workflow run:
`36593068249`

Job:
`109490879329`

Conclusion:
FAILURE.

## Result

The preregistered route requires `cs2cs` to be available on the standard
GitHub runner without package installation.

Observed failure:

`F_PE_ELASTIC39_FAIL cs2cs unavailable`.

Therefore the PROJ command-line route is not available under the current
dependency-free execution environment.

## Decision

Classification:

`ROUTE_FALSIFIED_PROJ_CLI_UNAVAILABLE`.

ELASTIC39 does not admit:
- CRS transformation;
- a PROJ package dependency;
- implicit package installation;
- production use of command-line transformation.

A separate research workunit may characterize another already-installed
standard toolchain, but this negative result remains authority.
