# F-PE-NLGLOB14E closeout — complete dynamic-top research policy qualification

Date: 2026-09-29

Final status:

`BLOCKED_NLGLOB14E_DIAGNOSTIC_OBSERVABILITY`

Numerical outcome:

`96 / 96 COMPLETE`

Canonical base incorporated before closeout:

`integration/f-ci-canonical@7b34fb5a980b647423d8c5062d0ec64f0568e0f7`

Qualification authority:

- run `36562781585`;
- job `109387398807`;
- conclusion: SUCCESS.

## Closure

NLGLOB14E completes the full frozen 96-case dynamic-top bank numerically.

Observed:

- 96/96 cases complete;
- process failures: 0;
- nonfinite completed states: 0;
- max accepted-interval ledger about `4.84e-14 cm`;
- max cumulative ledger about `6.06e-14 cm`;
- saturation-mode entries: 8;
- persistent saturated-mode intervals: 38;
- smooth no-event TG order remains about `2.048`.

No terminal failure reason remains.

## Why the workunit is not yet marked qualified

The frozen evaluator attempted to prove that no trajectory re-entered saturation-event localization after persistent saturated-mode entry by checking for exactly one `NLGLOB14A_ROOT` record.

That assumption is not valid in the assembled materialization chain.

The later NLGLOB14C event-switch layer replaces the successful root record with its own switch/entry diagnostics.

The eight event trajectories therefore show:

- exactly one saturated-mode entry;
- persistent mode intervals all `OK=1`;
- full requested horizon completion;
- but zero separately visible root records.

The numerical mechanism passes; the explicit observability gate is not yet directly evidenced.

## Scientific interpretation

No solver, mass, route, state or temporal-order defect is exposed by NLGLOB14E.

The remaining blocker is instrumentation-only.

The next workunit must make saturation-event localization attempts explicitly observable without changing solver behavior.

## Direct successor

Open:

`F-PE-NLGLOB14E1 — explicit post-entry event-attempt observability`.

The successor must:

1. use the identical NLGLOB14E numerical postimage;
2. add explicit diagnostics for every saturation-root localization attempt;
3. distinguish attempts before and after saturated-mode entry;
4. prove zero post-entry attempts for event trajectories;
5. rerun the complete 96-case bank and smooth regression;
6. leave all solver/state-machine behavior unchanged.

A positive observability rerun may upgrade the numerical 96/96 result to:

`QUALIFIED_COMPLETE_DYNAMIC_TOP_RESEARCH_POLICY`.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14E

BASELINE: `240a8a92b6403ebc8c749199b16fe44c971ee9d7`

BRANCH: `research/f-pe-nlglob14e-full-dynamic-policy`

STATUS: blocked only by diagnostic observability

IMPLEMENTATION STATUS: complete research temporal policy assembled in test harness

TEST STATUS: full 96-case bank PASS numerically

QUALIFICATION STATUS: `BLOCKED_NLGLOB14E_DIAGNOSTIC_OBSERVABILITY`

NEXT SAFE STEP: diagnostic-only NLGLOB14E1 rerun

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
