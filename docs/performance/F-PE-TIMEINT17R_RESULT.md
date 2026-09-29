# F-PE-TIMEINT17R result — reopened same-route dynamic-top qualification

Date: 2026-09-29

Status:

`QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE`

Canonical base:

`integration/f-ci-canonical@69f10afaff5781ee4980dee3f1e63c898a0f4b4b`

Canonical rechecked before result persistence through:

`integration/f-ci-canonical@d4d70ca5b776385db8f0ca9ffa9c9dfa5625c705`

The intervening canonical delta does not alter the TIMEINT17/NLGLOB14 execution surface, dynamic-top provider, test driver or HeadCalc authority used here.

Qualification authority:

- workflow run: `36563988024`;
- job: `109391349634`;
- conclusion: SUCCESS.

## Frozen question

After the NLGLOB research chain removed the endpoint-globalization and saturation-regime blockers, does the complete assembled research policy satisfy the original TIMEINT17 same-route dynamic-top qualification gates?

## Coverage

PASS.

The exact 96-case dynamic-top bank executed.

TG:

- 12/12 material-route ladders complete;
- all four dt levels complete in every ladder.

KLAG:

- all 48 matched comparison trajectories complete.

Process failures:

`0`.

## Dynamic-top temporal order

Median refined TG top-head order:

`1.9893690674357405`.

Median refined TG top-moisture order:

`1.9829603939589149`.

Individual refined head ladders >=1.5:

`10 / 12`.

The two sub-1.5 ladders are:

- O05 / HEAD: about `0.8172`;
- O05 / RUNOFF: about `0.8168`.

These ladders include the qualified saturation-entry/persistent-saturated temporal regime and are not dropped from the bank.

The frozen gate requires at least 9/12 ladders >=1.5, so the aggregate same-route order authority passes.

One B12/FLUX top-moisture order is numerically degenerate under the existing TIMEINT16C order estimator and is reported as null; it is not used to fabricate a passing order.

## Conservation and constitutive consistency

PASS.

- max accepted-interval physical ledger: about `4.84e-14 cm`;
- max cumulative physical ledger: about `6.06e-14 cm`;
- max theta/head roundtrip: about `1.11e-16`;
- max native endpoint balance residual: about `3.85e-10 cm/d`;
- predicted-K diagnostics finite and nontrivial.

All are within the frozen gates.

## Route/state and semantic guards

PASS.

- all completed states finite;
- all terminal reasons: `COMPLETE_SAME_ROUTE`;
- no post-entry saturation-root attempt;
- all persistent saturated intervals successful;
- at most one saturated-mode entry per trajectory.

## Work

Median deterministic TG work per nominal step relative to matched KLAG:

`1.0`.

Frozen maximum:

`1.20`.

PASS.

## Frozen classification

`QUALIFIED_TG_DYNAMIC_TOP_SAME_ROUTE`.

The original TIMEINT17 P0 same-route blocker is removed.

## Scientific interpretation

The earlier TIMEINT17 failure was not evidence that provider-consistent Thomas-Gladwell cannot support dynamic-top operation.

The blocker was a composite of:

1. endpoint stagnation at arithmetic storage-representation limits;
2. missing saturation-entry event semantics;
3. missing persistent post-saturation temporal regime state.

Once those are represented explicitly, the full dynamic-top bank is robust and the original same-route qualification gates pass without weakening physical mass conservation or solver tolerances.

The two O05 saturated-route ladders remain lower-order across the nominal dt sequence, but the preregistered bank-wide order gates still pass. This should remain visible as bounded evidence, not be hidden by averaging.

## Consequence

TIMEINT17 may now be updated from its original blocked state to a positive same-route qualification.

Remaining downstream work is separate:

- physical release/desaturation from persistent saturated mode;
- other dynamic-top event/release semantics where required;
- only after those semantics close positively: TIMEINT18 variable-step TG/LTE control.

## Production boundary

Research/test-only.

No production `src/**` change.

No default or numerical tolerance change.

`LEGACY_NUMERICS` remains production default.
