# F-PE-NLGLOB14N1 result — fine-dt saturation-entry root-trial failure attribution

Date: 2026-09-29

Status:

`NLGLOB14N1_ROOT_TRIAL_SOLVER_FAILURE`

Canonical base:

`integration/f-ci-canonical@a6e4579a98b127eb95f271e855aafe9d1e394c80`

Qualification authority:

- workflow run: `36570666847`;
- job: `109413648963`;
- conclusion: SUCCESS.

## Frozen target

The single blocked NLGLOB14N fixture:

- O05;
- TG;
- wet-entry route HEAD;
- dt = `7.8125e-6 d`;
- horizon = `0.05 d`.

The blocker reproduces at step 82.

## Attributed failure

The first failing NLGLOB14A root trial occurs at:

- root iteration: 3;
- phi_lo: about `0.1371085690`;
- phi_hi: about `0.2056628535`;
- phi_mid: about `0.1713857113`;
- trial dt: about `1.338950869e-6 d`.

The underlying terminal reason before NLGLOB14A overwrites it is:

`ENDPOINT_SOLVE_FAILURE`.

The corresponding solver status is:

`2`.

All route diagnostics remain HEAD-route consistent:

- origin route = 2;
- predictor route = 2;
- endpoint route = 2;
- accepted route = 2.

Therefore the frozen classification is:

`NLGLOB14N1_ROOT_TRIAL_SOLVER_FAILURE`.

## Physical admissibility

The target trajectory remains finite up to the blocker.

Physical mass remains clean:

- max accepted-interval ledger about `2.61e-14 cm`;
- cumulative ledger about `5.31e-16 cm`.

The failure is therefore not caused by physical mass loss, route inconsistency or a nonfinite accepted state.

## Scientific interpretation

The finest HEAD NLGLOB14N case is blocked during saturation-entry root localization by endpoint-solver robustness on a very small root-trial substep.

This occurs before persistent saturated-mode entry and well before the dry-phase retreat event.

Therefore the blocked HEAD retreat-convergence result cannot be interpreted as evidence against retreat-event convergence.

The repair question is now narrower: why does the existing endpoint solve fail for this small saturation-root trial while the surrounding accepted trajectory remains physically valid?

## Consequence

Any repair must be separately preregistered and must target the root-trial endpoint solve only.

Do not change:

- NLGLOB14N retreat-event definition;
- NLGLOB14N convergence threshold;
- dt ladder;
- route semantics;
- physical mass authority.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No solver or release policy changed.

`LEGACY_NUMERICS` remains production default.
