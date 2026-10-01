# F-PE-MIQUAL01 execution correction

Date: 2026-10-01

Status: `EXECUTION_INVALID_PRE_EXPOSURE_HARNESS_FIX`

First workflow run:

- run: `36819187731`;
- job: `110230835982`;
- conclusion: FAILURE.

## Reason

The first MIQUAL01 workflow failed before any scientific trajectory result was exposed.

The current canonical `tests/fpe/compile_fpe_timeint03_closure.py` dependency scanner used a USE regex without a word boundary after `use`. In the copied Z43E trajectory harness this misread an identifier beginning with `use_` as a module name and reported:

`unresolved modules: _reduced`

## Correction

MIQUAL01 added a workunit-local compile helper using the already-qualified Z43E exact USE parser:

`^\s*use\b...`

The scientific contract was unchanged:

- same 8 frozen cases;
- same physics;
- same MAXIT16 evidence profile;
- same forcing;
- same gates;
- same manager source;
- same canonical baseline.

No scientific output from run `36819187731` is used.

The corrected qualification authority is workflow run `36819243347`.
