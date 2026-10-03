# F-PE-NLGLOB14N2 result — fine-dt root-trial endpoint-solver decomposition

Date: 2026-09-29

Status:

`RETRY_ADVISED_AT_ROOT_TRIAL`

Canonical base:

`integration/f-ci-canonical@12e12538f043c6716086615ea51c8b87610600c4`

Qualification authority:

- workflow run: `36583443477`;
- job: `109457419142`;
- conclusion: SUCCESS.

## Frozen target

Single finest HEAD fixture from NLGLOB14N:

- O05;
- TG;
- HEAD;
- dt = `7.8125e-6 d`;
- horizon = `0.05 d`.

The known blocker reproduces at saturation-entry root localization, step 82.

## Solver decomposition

The first failing root trial occurs at:

- root iteration: 3;
- phi_lo: about `0.1371085690`;
- phi_hi: about `0.2056628535`;
- phi_mid: about `0.1713857113`;
- trial dt: about `1.338950869e-6 d`.

Existing solver diagnostics at that failing trial:

- status: `2`;
- retry advised: yes;
- diagnostic route: `legacy-reference-retry`;
- nonlinear iterations: `8`;
- backtracking attempts: `8`;
- Jacobian builds: `8`;
- linear solves: `8`;
- internal retries: `1`;
- alternative solver calls: `0`.

The underlying terminal reason remains `ENDPOINT_SOLVE_FAILURE` at the TIMEINT17 harness level because the harness maps any non-converged solver status to that label.

## Frozen classification

Because the solver explicitly returns retry-advised semantics for the root trial:

`RETRY_ADVISED_AT_ROOT_TRIAL`.

This classification takes precedence over interpreting the equal 8-count diagnostics as an independently established nonlinear or backtracking failure mode.

## Physical admissibility

The accepted trajectory before the root trial remains finite and mass-clean:

- max accepted-interval ledger about `2.61e-14 cm`;
- cumulative ledger about `5.31e-16 cm`.

Route consistency remains HEAD.

## Scientific interpretation

The finest HEAD blocker is not a hard solver-contract failure.

The reference solver asks the caller to reduce the trial step.

Inside ordinary transaction execution that is a valid retry signal.

Inside the current NLGLOB14A saturation-root bisection, however, this retry-advised outcome is placed in the generic `eligible=.false.` path and is therefore promoted to `SATURATION_ROOT_TRIAL_OTHER_FAILED`, aborting the root localization.

The next question is therefore a bounded root-controller policy question, not a tolerance-tuning question:

can retry-advised root trials be treated as non-accepted upper-bracket trials that contract the bisection interval, while restoring the saved accepted state exactly?

## Consequence

A separate preregistered research successor may test that single controller interpretation.

It must not:

- increase MAXIT;
- increase backtracking;
- relax BALTOL or head tolerances;
- accept a retry-advised candidate;
- mutate committed state from a failed trial;
- change the retreat-event definition or NLGLOB14N convergence gate.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No root-controller or release policy changed.

`LEGACY_NUMERICS` remains production default.
