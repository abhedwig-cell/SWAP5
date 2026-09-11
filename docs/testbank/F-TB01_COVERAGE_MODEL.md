# F-TB01 — Coverage Model

## Purpose

Coverage is claim-based and risk-based. File coverage or a green broad workflow is useful engineering evidence, but it is not sufficient proof of scientific coverage.

## Coverage axes

Every registered case or frozen matrix should map the dimensions that materially define its claim:

1. testbank level `TB-L0` through `TB-L12`;
2. physical process/component and active physics switches;
3. soil-water solver and numerical policy;
4. parameter, soil and crop class;
5. forcing and boundary-condition class;
6. initial/persistent state and restart position;
7. time interval/event class;
8. standalone, MultiSWAP or coupled composition;
9. transaction outcome: accepted, rejected/retry or rollback;
10. oracle class and tolerance version;
11. water-mass gate applicability;
12. execution profile and cost class;
13. platform/compiler identity where material;
14. negative/adversarial dimensions and unsupported-scope expectations.

## Required coverage views

The registry shall be able to answer at least:

- which scientific claims have an applicable independent or higher-grade oracle;
- which water-bearing paths carry a hard mass gate;
- which persistent states have continuous-vs-split restart evidence;
- which cases have standalone/serialized/parallel equivalence evidence;
- which coupling paths test both interface conservation and head-residual policy;
- which alternative solvers have an explicitly bounded admitted scope and Full Richards comparison;
- which difficult columns are in bounded-cost/performance qualification;
- which canonical capabilities have moving-current preservation rather than only historical evidence;
- which known legacy defects have explicit regression/intentional-difference classification;
- which architecture invariants have positive and negative tests.

## Negative tests

Negative tests are first-class cases. Required families include invalid or unsupported physical combinations, stale checkpoint/candidate rejection, rejected-trial nonmutation, out-of-scope alternative-solver use, missing oracle/tolerance provenance, missing mandatory mass-ledger terms, source/evidence authority mismatch and attempts to weaken a frozen tolerance without a new version.

A negative test passes by proving the system fails closed in the documented way. A skipped unsupported case is not a PASS unless the oracle explicitly expects `UNSUPPORTED`.

## Pairwise and risk-based combinations

Integrated physics uses pairwise/risk-based coverage rather than a full Cartesian product. High-risk seams receive dedicated matrices, including surface boundary × hydraulics, ET × root uptake, drainage × groundwater, frost × hydraulics, macropore × surface boundary, restart × optional state, MultiSWAP × rejection/rollback and coupling × adaptive window.

## Coverage status vocabulary

`COVERED_CURRENT`, `COVERED_HISTORICAL_ONLY`, `PARTIAL`, `REGISTERED_FUTURE`, `UNSUPPORTED_BY_DESIGN` and `GAP`.

`COVERED_CURRENT` requires exact current-source evidence. F-TB01 may register existing authorities and future gaps but does not promote them between evidence classes.

## Release rule

A release profile is built from an immutable manifest. Release qualification reports executed case IDs and versions, not an untraceable hand-entered total. Missing mandatory cases, missing hard mass gates or stale/mismatched evidence fail closed.