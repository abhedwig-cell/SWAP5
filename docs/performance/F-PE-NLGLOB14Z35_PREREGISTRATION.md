# F-PE-NLGLOB14Z35 preregistration — production-shaped manager physical binding smoke

Date: 2026-09-30

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Parent authority:

- Z34: `QUALIFIED_Z34_MANAGER_SEAM_READY`;
- Z33: `QUALIFIED_Z33_READY_FOR_PRODUCTION_SHAPED_MANAGER_PROTOTYPE`;
- Z29/Z31R: reduced moving-interface physics is physically viable in the qualified O05 scope;
- Z32: no material same-origin local equation defect is identified.

## Purpose

Bind the already-qualified reduced moving-interface physics to the Z34 manager seam in one small production-shaped executable smoke.

Z35 is not a broad holdout and not a long performance campaign.

## Frozen architecture

The full accepted physical state remains sole authority.

The manager may:

1. derive an active reduced view;
2. build a reduced typed request;
3. execute a reduced physical solve;
4. reconstruct the saturated lower tail;
5. materialize a full-shaped candidate;
6. select reduced, explicit full fallback or explicit bypass;
7. leave commit/rollback authority outside the manager.

## Frozen physical fixture

Use one 16-node O05-inspired qbot=0 hydrostatic-saturated-tail smoke state with:

- contiguous saturated tail 13:16;
- active reduced dimension n=13;
- guard node 13 retained in the nonlinear solve;
- nodes 14:16 reconstructed analytically;
- fixed dry top/surface-flux semantics;
- one short nominal interval.

The smoke does not need to reproduce the full long O05 forcing trajectory.

## Frozen reference comparison

From one identical full origin:

- compute one 16-node full-reference candidate;
- compute one 13-node reduced candidate using the qualified reduced equations;
- reconstruct nodes 14:16;
- materialize the reduced result back to a 16-node candidate;
- compare physical state, flux and mass diagnostics.

Comparison gates:

- max |h_reduced-full| <= 5e-7 cm;
- max |theta_reduced-full| <= 5e-10;
- top-flux difference <= 5e-10 cm/d;
- nominal ledger difference <= 5e-8 cm;
- tail identity equal;
- candidate remains full-shaped after manager materialization.

These are smoke comparison gates only.

## Mandatory route tests

The executable must also prove:

1. eligible reduced route is selected;
2. explicit forced reduced failure selects exact full fallback;
3. full-dimension/ineligible view selects explicit bypass;
4. failed reduced attempt leaves accepted origin unchanged;
5. diagnostics expose full nodes, active nodes, route and fallback reason.

## Frozen implementation preference

Prefer a small research-only reduced-physics service callable behind `mod_moving_interface_manager`.

Reuse existing:

- typed request/result/state contracts;
- active_nodes-aware workspace;
- existing linear-solver primitives where practical;
- manager candidate materialization/fallback logic.

Do not create a second committed-state owner.

## Frozen classifications

### `QUALIFIED_Z35_MANAGER_PHYSICAL_BINDING_SMOKE`

Require all physical comparison and route/rollback gates to pass.

### `Z35_REDUCED_PHYSICAL_MISMATCH`

Reduced/full physical smoke comparison fails.

### `Z35_FALLBACK_OR_BYPASS_FAILED`

Fallback/bypass selection is not exact or unambiguous.

### `Z35_TRANSACTION_LEAK`

Reduced failure mutates accepted authority.

### `Z35_EXECUTION_FAILED`

Compile/execution failure not covered above.

## Consequence

A positive Z35 result authorizes the first small application/profile holdout set and focused end-to-end timing benchmark.

It does not authorize production default change.

## Stop rules

Do not:

- broaden to BOFEK-wide runs inside Z35;
- alter Z30/Z31 historical gates;
- fit a correction;
- add mass redistribution;
- add anti-chatter logic;
- change production default.

## Recovery point

WORK UNIT: F-PE-NLGLOB14Z35

BASELINE: `df17629888b8b6e06f42bcde4a661cdedf9ee5a8`

BRANCH: `research/f-pe-nlglob14z35-manager-physical-binding-smoke`

NEXT SAFE STEP: implement and execute the focused manager physical-binding smoke.

## Production boundary

Research prototype only.

`LEGACY_NUMERICS` remains production default.
