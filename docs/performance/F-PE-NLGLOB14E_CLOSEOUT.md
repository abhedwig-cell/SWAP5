# F-PE-NLGLOB14E closeout — complete dynamic-top research policy qualification

Date: 2026-09-29

Final status:

`QUALIFIED_COMPLETE_DYNAMIC_TOP_RESEARCH_POLICY`

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

## Diagnostic reconciliation

The first full-bank postimage exposed an instrumentation-lineage mismatch rather than a numerical failure. The assembled NLGLOB14C/D materialization replaces the earlier standalone root record with switch/entry diagnostics. The diagnostic-only correction therefore checks the state-machine evidence actually present in the assembled postimage: at most one saturated-mode entry, one successful switch per entry, and only successful persistent-mode intervals thereafter.

The final unchanged numerical postimage reports `diagnostic_ok=true` on run `36562781585`, job `109387398807`.

## Scientific interpretation

All preregistered full-bank gates now pass. The frozen same-route dynamic-top endpoint blocker is removed at research level without weakening mass, state, route or smooth-order authority.

## Direct successor

Open a separate physical desaturation/release semantics workunit. NLGLOB14E intentionally keeps the saturated mode persistent once entered, so a production-shaped state machine still requires a separately preregistered criterion for leaving that mode. Do not invent that release rule inside NLGLOB14E.

## Recovery point

WORKSTREAM: F-PE numerical performance / Richards temporal robustness

WORK UNIT: F-PE-NLGLOB14E

BASELINE: `240a8a92b6403ebc8c749199b16fe44c971ee9d7`

BRANCH: `research/f-pe-nlglob14e-full-dynamic-policy`

STATUS: closed positive

IMPLEMENTATION STATUS: complete research temporal policy assembled in test harness

TEST STATUS: full 96-case bank PASS numerically

QUALIFICATION STATUS: `QUALIFIED_COMPLETE_DYNAMIC_TOP_RESEARCH_POLICY`

NEXT SAFE STEP: preregister physical desaturation/release semantics

## Production boundary

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
