# F-PE-TIMEINT02 result — BDF2 operator consistency

Date: 2026-09-28

Status: `BLOCKED_IMPLICIT_OPERATOR_CONTRACT`

Canonical base:

`integration/f-ci-canonical@b13fb7b903044a82687a21814bfaa1f7e7cfa833`

Primary Actions authority:

- operator run: `36440910210`;
- attribution run: `36441368939`.

## Preregistered four-way matrix

### BE_KLAG

Current first-order storage + lagged K.

Result:

- 4/4 smooth cases complete;
- median refined top-head order: 0.943;
- 0/4 cases >=1.5;
- median deterministic work per step: 16.

This reproduces the expected first-order baseline.

### BDF2_KLAG

BDF2 storage + lagged K.

Result:

- 3/4 cases complete;
- median refined top-head order: 0.576;
- 0/4 cases >=1.5;
- work per step on completed runs approximately equal to BE_KLAG.

Therefore replacing only the storage derivative by BDF2 does not create a second-order Richards method.

This directly confirms the TIMEINT01 operator-consistency warning.

### BE_KIMPL / BDF2_KIMPL

Both initially returned solver status FAILED for every planned run.

TIMEINT02A showed this was not nonlinear nonconvergence.

At MAXIT 8, 16 and 32:

- 0/8 attribution runs complete in every arm;
- failure occurs at step 1;
- nonlinear iterations = 0;
- Jacobian builds = 0;
- linear solves = 0.

Source attribution:

`validate_legacy_request()` in the explicit Reference binding intentionally rejects:

`conductivity_implicit_mode /= 0`

with route:

`legacy-implicit-k-deferred`.

Therefore the endpoint-implicit K variants were never executed.

## Scientific conclusion

Two distinct results are established.

### Result 1 — lagged operator is order limiting

BDF2 storage with current SWKIMPL=0 coefficient lagging is not second-order-capable in the tested smooth envelope.

The modern integrator cannot be implemented as a storage-formula change alone.

### Result 2 — fully implicit operator is contract-blocked, not falsified

The candidate needed to test true endpoint operator consistency is currently excluded by the explicit solver contract.

The failure is architectural and pre-solve.

It is not evidence that fully implicit Backward Euler or BDF2 fails numerically.

## Implication

Before BDF2 can be adjudicated, SWAP5 needs a bounded test-only or qualified explicit-provider route for endpoint-updated conductivity.

That route must separately establish:

- exact constitutive K and dK/dh ownership;
- fixed-flux top compatibility;
- prescribed-flux/head bottom compatibility as needed;
- Jacobian correctness;
- convergence behavior;
- preservation of the current SWKIMPL=0 Reference route.

## Decision

TIMEINT02 does not qualify BDF2 for production.

It also does not reject BDF2 as an integrator family.

Final status:

`BLOCKED_IMPLICIT_OPERATOR_CONTRACT`.

## Required successor

`F-PE-TIMEINT03 — explicit fully implicit Richards operator qualification`.

TIMEINT03 should first expose SWKIMPL=1 through a test-only renamed binding and validate ordinary Backward Euler behavior.

Only if that succeeds should the BDF2_KIMPL order study be resumed.

No dynamic-top SWKIMPL=1 claim should be made in the first successor phase.
