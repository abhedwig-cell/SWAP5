# F-PE-MIQUAL01 execution correction — run 36819254055

Date: 2026-10-01

Status: `EXECUTION_INVALID_BEFORE_FIXTURE_EXECUTION`

The first MIQUAL01 qualification run did not expose scientific results.

It stopped during compilation before any frozen fixture executed.

Observed failure:

`unresolved modules: _reduced`

Attribution:

- the current canonical `tests/fpe/compile_fpe_timeint03_closure.py` uses a module-use regex without the historical word boundary after `use`;
- this can parse an identifier beginning with `use...` as a Fortran USE statement and synthesize a false module name such as `_reduced`;
- the Z43E-qualified helper contained `use\b` and did not have this false-positive behavior.

Correction boundary:

- restore only the missing regex word boundary in the compile helper;
- do not modify manager physics, fixtures, tolerances, forcing, geometry, gates, or classifications;
- rerun the same preregistered MIQUAL01 bank once.

Run 36819254055 is build-invalid and must not be used as scientific qualification evidence.
