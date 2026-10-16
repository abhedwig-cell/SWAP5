# F-PE-REPRO01 D5 — memory-state instrumentation

Date: 2026-09-26

Status: `PREREGISTERED_DIAGNOSTIC_ONLY`

## Trigger

Evidence through D4:

- fixed-build full live route: exact 8/20 status-6 failures;
- reduced exact first-corrector D2: rare status-6 failure reproduced;
- D2 failing solver signature: retry-advised after 16 nonlinear iterations, 108 backtracks and one internal retry;
- D3 default/zero-init/sNaN-check: 100/100 PASS per build;
- D4 one fixed ordinary binary: 2000/2000 PASS across OpenMP runtime controls.

The failure is therefore strongly sensitive to process/harness/build layout and has not been explained by ordinary OpenMP scheduling or simple compiler local initialization.

## Question

Is there observable invalid or uninitialized memory use on the exact first-corrector path?

## D5A — ASan/UBSan

Build the exact D1 probe with:

- `-O1 -g`;
- `-fsanitize=address,undefined`;
- `-fno-omit-frame-pointer`;
- existing Fortran runtime checks where compatible.

Run 100 fresh exact first-corrector processes.

Record any sanitizer diagnostic and process exit.

## D5B — Valgrind Memcheck

Build one debug exact probe with:

- `-O0 -g`;
- no practical approximation.

Run the first-corrector probe under Valgrind Memcheck with:

- `--track-origins=yes`;
- `--error-exitcode=99`;
- leak checking disabled as leak ownership is not the target.

Run at least 10 fresh processes, or stop after the first actionable invalid/uninitialized-use report.

If Valgrind is absent on the runner, install the standard Ubuntu package in the diagnostic workflow. This is test infrastructure only.

## Interpretation

Any sanitizer or Memcheck report on the executed exact path is actionable evidence and advances to source localization.

Absence of reports does not prove memory safety, but would move the next diagnostic toward numerical-state initialization/ordering rather than generic invalid memory access.

No production source change is admitted by D5.
