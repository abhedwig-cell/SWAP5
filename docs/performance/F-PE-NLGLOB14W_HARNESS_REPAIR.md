# F-PE-NLGLOB14W harness repair note

Date: 2026-09-29

The first NLGLOB14W workflow attempt, run `36604544998`, failed before scientific result exposure.

Classification:

`HARNESS_SYNTAX_FAILURE_BEFORE_RESULT_EXPOSURE`

Cause:

- the automated derivation of `tests/fpe/run_fpe_nlglob14w.py` from the qualified NLGLOB14U harness inserted literal escaped newline text into two Python dictionary expressions;
- Python therefore raised a `SyntaxError` before any NLGLOB14W fixture executed.

The Fortran build and all upstream materializers completed successfully before the Python syntax error.

Repair:

- commit `bc172c9d281a7695b033dc6a50f63aaefad983e2` replaces only the accidental literal escaped-newline text with actual line breaks;
- no preregistered hypothesis, fixture, horizon, numerical residual, transaction rule, mass gate, interface rule or classification is changed.

The failed run carries no scientific evidence and must not be interpreted as a falsification.

Next safe step:

run the unchanged preregistered NLGLOB14W gate on the repaired postimage.
