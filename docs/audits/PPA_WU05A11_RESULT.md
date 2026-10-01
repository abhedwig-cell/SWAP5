# PPA-WU05-A11 result — perched-zone carrier authority reconciliation

Date: 2026-10-01

Status: `BLOCKED_EXACT_PERCHED_CARRIER_RULE_NOT_RECOVERED`

Baseline: `integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48`

Preregistration commit: `0a36b968b536bf6bae17eaa050eb6f0a3adf9705`

## Reconciliation result

A10 is canonically admitted and closed. Its post-merge preservation run `36829313469` completed successfully on exact merge `190dad36a821f3a43f78f00fccf827c58cacedb6`. Documentation closeout PR #929 merged as canonical `ebea588070f7a44dbaea78169f2548c745061c48`.

The next bounded capability is perched/top saturated matrix-zone macropore exchange.

This choice is based on functional distance to the standard SWAP 4.3.1 route:

- A6 already contains source-bound perched exclusion in unsaturated absorption;
- A6 already contains the reusable SATFLOW evaluator and separate `interflow_sat` request;
- A6 source authority states that `QInIntSatDmCp` is saturated matrix-to-macropore inflow from the perched/top saturated zone;
- current A8/A9/A10 production composition deliberately suppresses this carrier.

This makes perched-zone activation a smaller and more source-continuous next step than within-corrector dynamic crack feedback, RossFast, or parallel MultiSWAP.

## What is source-authoritative now

Historical A6 authority recovered from PR #922 head `b5b123dcc4450dcc3c76a789ba749205fa8474b5` establishes:

- unsaturated active bottom is bounded by `min(ICpBtDm, ICpTpSatZon-1)`;
- compartments in the perched partly saturated matrix interval are excluded from unsaturated absorption;
- B1.11 MACRORATE calls SATFLOW twice for incoming saturated matrix water:
  - perched/top saturated zone -> `QInIntSatDmCp`;
  - main saturated zone -> `QInMtxSatDmCp`;
- both are internal matrix-to-macropore transfers.

Current canonical code faithfully retains the corresponding rate inputs and equations but intentionally does not derive the perched-zone request.

## Missing authority

The repository does not currently contain a canonically admitted rule that maps current FMR matrix state to the exact B1.11 perched-zone carrier:

- active flag;
- top compartment;
- bottom compartment;
- reference level;
- partial-boundary fraction/semantics.

The old A7 result explicitly listed the optional perched saturated-zone view as still missing from the FMR adapter.

The exact SWAP 4.3.1 archive used by A1 was not retrievable from the current Project/Library file surface in this execution. Therefore the missing carrier rule could not be re-read from the exact B1.11 source bytes here.

## Falsified shortcut

The route

`derive perched zone directly from pressure_head >= 0`

is **not admitted** by this workunit.

It may be physically plausible, but current repository authority does not prove that it reproduces B1.11 `ICpTpSatZon` / perched-zone construction, boundary fractions, or reference-level semantics. Implementing that shortcut would silently invent physics/interface behavior.

## Decision

`REAL_BLOCKER_EXACT_PERCHED_CARRIER_AUTHORITY_REQUIRED`

No production code, mass tolerance, physics formula, or persistence schema is changed.

A11 remains the correct next workunit, but implementation is held at G1 until the exact perched-zone source/carrier rule is recovered from:

1. the byte-exact B1.11 oracle already identified by A1; or
2. an existing repository artifact that explicitly records the full `ICpTpSatZon` construction and SATFLOW call arguments.

Once G1 closes, the expected implementation is small: a derived non-persistent FMR perched hydraulic view feeding existing A6 request fields, followed by active mass/replay/restart qualification and A8/A9/A10 preservation.

## Why the alternatives are not selected first

- Arbitrary rapid-drain levels require a source-authoritative within-compartment volume/interpolation rule not present in current canonical A10.
- Dynamic crack feedback changes geometry and matrix displacement inside the corrector and is materially more invasive.
- RossFast and parallel MultiSWAP expand numerical/execution policy before the standard Reference-Richards macropore physics envelope is complete.

The frozen Status-A denominator remains unchanged.
