# F-PE-TIMEINT12A preregistration — fully implicit BE on corrected dynamic-top

Date: 2026-09-29

Status: `PREREGISTERED_BEFORE_RESULTS`

Parent:

F-PE-TIMEINT12 derivative qualification.

## Purpose

Test the complete fully implicit Richards operator on the BOFEK00 corrected dynamic-top route before introducing BDF2 temporal history.

This phase is still test-only.

## Test-only derivative binding

Materialize the TIMEINT12-qualified `dHsurf/dh_top` into the dynamic-top provider only for the bounded test profile:

- conductivity mean method 1;
- default MvG hydraulics;
- zero potential surface evaporation;
- linear runoff exponent 1;
- existing BOFEK00 analytical runoff route.

No production source file is modified.

## Candidate

Fully implicit Backward Euler:

- `SWKIMPL=1`;
- dynamic-top provider with qualified fully implicit surface derivative;
- current BE storage derivative;
- current solver tolerances;
- BALTOL02 representation-aware floor;
- bottom mode 2 / zero bottom flux;
- no macropore/root/drainage composition.

Comparator:

- admitted BOFEK00 fixed-K `SWKIMPL=0` BE route at identical fixed dt.

The comparator is not temporal truth. It is used to quantify physical/operator change and solver work.

## Case bank

Use B01, B12, O05, O14 across:

- MOIST: h0=-50 cm, rain=8 cm/day;
- WET: h0=-20 cm, rain=12 cm/day;
- POND: h0=-5 cm, rain=25 cm/day.

Use fixed dt:

- 0.005 d;
- horizon 0.12 d;
- 24 accepted steps when complete.

This deliberately includes the BOFEK00 wet/ponding boundary route.

## Metrics

Per case and mode:

- completion;
- accepted steps;
- nonlinear iterations;
- backtracks;
- Jacobian builds;
- linear solves;
- runoff;
- ponding;
- storage;
- terminal top/mid/bottom head;
- max ledger residual;
- final boundary route/regime.

## Frozen advancement gates

Fully implicit BE advances to dynamic-top BDF2 study only if:

1. all 12 SWKIMPL=1 cases complete;
2. no solver rejection/floor failure;
3. max ledger <=5e-8 cm;
4. no nonfinite state;
5. every POND case completes;
6. median deterministic work ratio KIMPL/KLAG <=1.25;
7. no individual case work ratio >1.50.

No equivalence gate to SWKIMPL=0 is imposed because fully implicit conductivity defines a different, more temporally consistent operator. Physical differences are reported, not used as correctness failure unless mass/state validity breaks.

## Stop rule

If fully implicit BE fails these robustness/cost gates, dynamic-top BDF2 is blocked.

If it passes, preregister TIMEINT12B before any BDF2 dynamic-top trajectory is exposed.

## Production boundary

No production source change.
