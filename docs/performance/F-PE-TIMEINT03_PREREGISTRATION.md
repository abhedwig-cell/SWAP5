# F-PE-TIMEINT03 preregistration — explicit fully implicit Richards operator qualification

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@0d131bfc0d7b490b936b4315b17d175342e29ee6`

Parent authority:

- TIMEINT01: current Reference SWKIMPL=0 is an empirically supported first-order semi-implicit scheme;
- TIMEINT02: BDF2 storage with lagged K is not second-order-capable;
- TIMEINT02A: the explicit Reference binding rejects SWKIMPL=1 before HeadCalc through `legacy-implicit-k-deferred`.

## Purpose

Determine whether the existing HeadCalc SWKIMPL=1 operator is usable through the explicit provider path once the binding-level deferral is removed test-only.

Do not test BDF2 until ordinary Backward Euler with endpoint-updated conductivity is characterized.

No production source change.

## Test-only binding

Materialize the current `mod_reference_richards_legacy_binding` under a distinct test module name.

The only semantic change allowed in P0 is:

- admit `conductivity_implicit_mode = 0 or 1`;
- continue rejecting values outside that set.

All other request validation, solver/result mapping, provider contracts and HeadCalc source remain canonical.

The production binding remains untouched.

## P0 matrix — ordinary Backward Euler

Top boundary:

- explicit fixed flux.

Bottom boundary:

- prescribed zero flux, mode 2.

Hydraulic cases:

- B01, infiltration 2 cm/day;
- B01, infiltration 4 cm/day;
- O05, infiltration 2 cm/day;
- O05, infiltration 4 cm/day.

Initial head:

- -100 cm.

Horizon:

- 0.04 d.

Fixed dt ladder:

- 0.010 d;
- 0.005 d;
- 0.0025 d;
- 0.00125 d.

Compare:

- BE_KLAG, SWKIMPL=0;
- BE_KIMPL, SWKIMPL=1.

BALTOL02 effective floor and all head tolerances remain unchanged.

## P0 metrics

Per run:

- completion;
- endpoint top/mid/bottom head;
- storage;
- nonlinear iterations;
- backtracks;
- Jacobian builds;
- linear solves;
- alternative solver calls.

Compute refined top-head convergence order for both routes.

## P0 gate

SWKIMPL=1 explicit-provider operator advances only if:

1. all 16 BE_KIMPL runs complete;
2. no fatal contract/error route occurs;
3. median refined top-head order lies in [0.7, 1.3], consistent with first-order BE;
4. no individual refined order is grossly nonphysical because of solver failure/path switching;
5. median work per step <= 2.0 times BE_KLAG.

This is an operator usability gate, not a performance qualification.

## P1 boundary

Only after P0 passes may TIMEINT03 materialize BDF2 storage with the same test-only fully implicit binding.

P1 retains the TIMEINT02 BDF2 second-order gate:

- 4/4 cases complete over the full ladder;
- median refined top-head order >= 1.6;
- at least 3/4 individual refined orders >= 1.5;
- median work per step <= 1.5 times BE_KIMPL.

No dynamic-top SWKIMPL=1 claim is allowed in TIMEINT03.
