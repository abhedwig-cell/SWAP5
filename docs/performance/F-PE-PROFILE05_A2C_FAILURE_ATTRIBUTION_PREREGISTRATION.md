# F-PE-PROFILE05 A2C failure-arm attribution preregistration

Date: 2026-09-26

Status: `PREREGISTERED_OBSERVATION_ONLY`

## Trigger

The six-replica A2C reproducibility gate produced:

- 4 successful jobs;
- 2 failed jobs with SWAP participant status `6 (TRIAL_FAILED)`.

The inherited APPROX02 runner executes exact first and A2C second, but because it uses shell `set -e`, a Python failure exits before the runner prints which arm failed.

Therefore the mixed 4/6 result cannot yet be attributed specifically to A2C.

## Question

When the live FGC44 test produces status 6, does the failure occur in:

- the exact arm;
- the A2C arm;
- or both across independent replicas?

## Protocol

Use the same build logic, same source code, same pinned dependencies, same exact arm and same A2C `1e-8` arm as:

`tests/fpe/run_fpe_approx02_a2_modflow_e2e.sh`

The only harness change is shell-level provenance:

- print the arm before execution;
- capture the Python return code without immediate `set -e` termination;
- report `EXACT=PASS/FAIL` and `A2C=PASS/FAIL`.

Run six independent replicas.

No numerical or production source setting changes are allowed.

## Interpretation

Do not classify A2C as the cause until arm attribution exists.

If exact fails in any replica, the issue is broader than the A2C approximation envelope and must be investigated as coupled-test/runtime nondeterminism or an exact-route robustness problem.

If exact is 6/6 green and A2C alone fails, A2C coupled robustness is not reproducible.

If both are 6/6 green, the preceding mixed failures require a separate environment/runtime reproducibility investigation before performance conclusions are drawn.
