# F-PE-TIMEINT17 requalification result — complete same-route dynamic-top policy

Date: 2026-09-29

Status:

`QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE_RESEARCH_POLICY`

Canonical base:

`integration/f-ci-canonical@fb8e5fc203dffc7f102165d01cd0374a6366ba82`

The intervening canonical delta since preregistration is ELASTIC20-only and does not change the TIMEINT17/NLGLOB temporal dependency surface.

Qualification authority:

- workflow run: `36563812241`;
- job: `109390767276`;
- conclusion: SUCCESS.

## Dynamic-top bank

The complete assembled policy requalifies the full frozen bank:

- complete cases: `96 / 96`;
- process failures: `0`;
- incomplete cases: `0`;
- nonfinite completed states: `0`;
- unsafe terminal reasons: `0`.

Observed event/state-machine diagnostics:

- saturation-root attempts: `8`;
- saturated-mode entries: `8`;
- persistent saturated-mode intervals: `38`;
- post-entry root-attempt violations: `0`;
- diagnostic contract: PASS.

Physical mass:

- max accepted-interval ledger about `4.84e-14 cm`;
- max cumulative ledger about `6.06e-14 cm`.

## Smooth temporal-order preservation

The original smooth TIMEINT16C bank remains positive:

- 4/4 ladders complete;
- median refined top-head order about `2.04787`;
- median refined top-theta order about `2.04787`;
- 4/4 individual head ladders >=1.5;
- median work ratio versus KLAG BE: `1.0`;
- physical mass at roundoff;
- constitutive and native endpoint balance gates pass.

## Frozen classification

`QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE_RESEARCH_POLICY`.

All frozen requalification gates pass.

## Scientific interpretation

The original TIMEINT17 endpoint-globalization blocker is superseded for same-route dynamic-top mechanism qualification.

The positive mechanism now consists of:

1. provider-consistent second-order TG in the unsaturated regime;
2. S0/R0 representation-aware endpoint exhaustion certificates;
3. bracketed first-saturation event localization;
4. exact event remainder integrated with head/KLAG;
5. persistent saturated head/KLAG temporal mode;
6. no event-root re-entry after persistent saturated-mode entry.

The previous TIMEINT17 negative authority remains historically valid for the earlier solver composition. It is no longer the current blocker under the assembled research policy.

## Remaining boundary

This requalification does not establish physical release/desaturation semantics from persistent saturated mode.

It also does not yet qualify:

- HEAD -> FLUX release localization;
- runoff deactivation localization;
- variable-step TG/LTE;
- production source admission.

Those remain separate downstream work.

## Production boundary

Research only.

No production `src/**` change.

No numerical default or physical acceptance authority changed.

`LEGACY_NUMERICS` remains production default.
