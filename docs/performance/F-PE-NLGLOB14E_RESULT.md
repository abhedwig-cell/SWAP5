# F-PE-NLGLOB14E result — complete dynamic-top research policy qualification

Date: 2026-09-29

Status:

`BLOCKED_NLGLOB14E_DIAGNOSTIC_OBSERVABILITY`

Numerical outcome:

`96 / 96 COMPLETE`

Canonical base:

`integration/f-ci-canonical@240a8a92b6403ebc8c749199b16fe44c971ee9d7`

Qualification authority:

- workflow run: `36562592611`;
- job: `109386754328`;
- conclusion: SUCCESS.

## Frozen full-bank outcome

All 96 frozen dynamic-top cases complete the requested horizon.

Observed:

- complete cases: `96 / 96`;
- process failures: `0`;
- nonfinite completed states: `0`;
- physical mass: PASS;
- max accepted-interval ledger about `4.84e-14 cm`;
- max cumulative ledger about `6.06e-14 cm`;
- saturation-mode entries: `8`;
- persistent saturated-mode intervals: `38`;
- smooth no-event TG order: about `2.048`.

No terminal reason remains.

## Diagnostic-gate failure

The preregistered evaluator also required a diagnostic check intended to prove that no trajectory re-entered saturation-event localization after persistent saturated-mode entry.

The implementation used:

`root_count == 1`

for trajectories with one saturated-mode entry.

That assumption is incorrect for the assembled NLGLOB14C/D instrumentation.

The successful NLGLOB14A root diagnostic is replaced by the NLGLOB14C switch/entry diagnostics during the later materialization chain.

Therefore all eight event trajectories show:

- `entry_count = 1`;
- `persistent_ok = true`;
- full horizon completion;
- but `root_count = 0`.

This makes the evaluator set:

`diagnostic_ok = false`

even though the state-machine diagnostics themselves show correct persistent-mode behavior.

## Classification

The preregistered broad classifier returned:

`CLOSED_NLGLOB14E_DYNAMIC_POLICY_PHYSICAL_ADMISSIBILITY_FAILED`.

That label must not be interpreted as a physical failure.

No mass, finite-state, route, solver or horizon-completion gate failed.

The actual blocker is diagnostic observability.

Therefore the bounded result authority is:

`BLOCKED_NLGLOB14E_DIAGNOSTIC_OBSERVABILITY`.

## Consequence

Do not change any solver or state-machine behavior.

Open a diagnostic-only successor that instruments saturation-root attempt count explicitly and reruns the identical 96-case postimage.

The corrected gate must be preregistered before rerun.

## Production boundary

Research only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
