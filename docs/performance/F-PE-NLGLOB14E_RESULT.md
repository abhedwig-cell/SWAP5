# F-PE-NLGLOB14E result — complete dynamic-top research policy qualification

Date: 2026-09-29

Status:

`QUALIFIED_COMPLETE_DYNAMIC_TOP_RESEARCH_POLICY`

Canonical base:

`integration/f-ci-canonical@240a8a92b6403ebc8c749199b16fe44c971ee9d7`

Qualification authority:

- corrected final workflow run: `36562781585`;
- job: `109387398807`;
- conclusion: SUCCESS.

The earlier run `36562592611` exposed a diagnostic-harness defect in the no-rebracketing predicate. Its numerical result was already 96/96 complete, but it was bounded as `QUALIFIED_COMPLETE_DYNAMIC_TOP_RESEARCH_POLICY` until the predicate was corrected. No solver or state-machine behavior changed between the two runs.

## Frozen full-bank result

All 96 frozen dynamic-top cases complete the requested horizon:

`96 / 96 COMPLETE`.

Observed:

- process failures: `0`;
- incomplete cases: `0`;
- nonfinite completed states: `0`;
- unsafe terminal reasons: `0`;
- physical mass: PASS;
- max accepted-interval ledger about `4.84e-14 cm`;
- max cumulative ledger about `6.06e-14 cm`;
- saturation-mode entries: `8`;
- persistent saturated-mode intervals: `38`;
- no event localization occurs after persistent saturated-mode entry.

Both TG and KLAG complete across all four materials, all three routes and all four dt levels.

## Smooth no-event preservation

PASS.

The original smooth TIMEINT16C bank remains strongly second order:

- 4/4 ladders complete;
- median refined top-head order about `2.04787`;
- median refined top-theta order about `2.04787`;
- 4/4 individual refined head ladders >=1.5;
- physical/cumulative ledgers at roundoff;
- median deterministic work ratio versus KLAG BE: `1.0`.

Thus the assembled dynamic policy does not perturb the no-event TG mechanism.

## Complete qualified research policy

For TG trajectories:

### Unsaturated branch

Use provider-consistent endpoint-stage TG with the unchanged accepted-state formula.

Use unchanged S0/R0 research endpoint certificates.

### First saturation entry

When prospective accepted TG moisture crosses the constitutive saturation boundary:

1. localize the event using NLGLOB14A bracket-preserving bisection;
2. require the event-distance, route, finite-state and event-mass guards;
3. accept the event state internally;
4. integrate the exact nominal-interval remainder with existing head/KLAG;
5. enter persistent saturated temporal mode only after the event+remainder interval completes.

### Persistent saturated branch

For each later nominal interval after entry:

- use the existing head/KLAG formulation;
- reevaluate the dynamic-top provider normally;
- retain unchanged S0/R0 endpoint certificates;
- do not re-enter TG event localization.

KLAG comparison trajectories remain otherwise unchanged.

## Work diagnostics

Median deterministic work over the frozen bank:

- TG: `202.0`;
- KLAG: `180.5`.

These values are descriptive only and were not qualification gates.

Correctness was qualified before any work-policy optimization.

## Frozen classification

`QUALIFIED_COMPLETE_DYNAMIC_TOP_RESEARCH_POLICY`.

All frozen gates pass.

## Scientific interpretation

The full same-route dynamic-top blocker is removed at research level on the frozen 96-case bank.

The evidence chain now supports:

1. second-order provider-consistent TG in the unsaturated regime;
2. representation-aware endpoint exhaustion without tolerance relaxation;
3. conservative saturation-event localization;
4. head/KLAG integration after saturation entry;
5. persistence of the saturated temporal regime across nominal steps.

The earlier failures were not one defect. They were a combination of:

- arithmetic representation-floor endpoint stagnation; and
- missing temporal regime semantics at saturation.

Both are now resolved in the assembled research policy.

## Remaining boundary

A physical release/desaturation criterion for leaving persistent saturated mode is not yet qualified.

The frozen horizon did not require one.

That release/event semantics question must be handled separately before production-shaped admission.

## Consequence

TIMEINT17 same-route dynamic-top qualification may now be reopened using the complete assembled research policy.

After positive TIMEINT17 closure, the sequence can proceed to:

1. explicit saturated-mode release/desaturation semantics;
2. dynamic-top event localization as required;
3. TIMEINT18 variable-step/LTE;
4. production-shaped integration and admission.

## Production boundary

Research only.

No production `src/**` change.

No numerical or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
