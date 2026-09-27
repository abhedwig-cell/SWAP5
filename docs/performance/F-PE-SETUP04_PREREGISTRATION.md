# F-PE-SETUP04 — production admission of scalable bootstrap identity/registry binding

Date: 2026-09-27

Status: `PREREGISTERED_PRODUCTION_ADMISSION`

Canonical base:
`integration/f-ci-canonical@4ee57d17a3793a58c792d5de9cdd0a38f9e7918a`

Research authority:
`F-PE-SETUP03 / PR #680`

Branch:
`work/f-pe-setup04-production-scalable-bootstrap`

## Qualified mechanism

SETUP03 qualified a combined large-N bootstrap repair:

1. replace O(N^2) tile-ID and ledger-ID prefix duplicate scans with deterministic global O(N log N) uniqueness validation;
2. during a freshly initialized participant registry, bind globally prevalidated tiles directly into the next fresh sequential slot rather than rescanning all slots for duplicate tile IDs and the first unused slot.

Research performance:
- N=1,000: 1.413929x app-initialize speedup;
- N=10,000: 8.302980x;
- N=40,000: 31.908534x;
- N=40,000 app initialize: about 3.604 s -> 0.113 s.

## Production implementation boundary

### Generic registry API

The existing ordinary `registry%bind` procedure and its semantics remain unchanged.

A separate explicitly named procedure is added:

`bind_prevalidated_fresh`

It may be used only by the production bootstrap after global tile-ID uniqueness has passed.

The dedicated path must fail closed unless:
- registry is initialized;
- tile/column/template/state/datum/materializer/policy validity is identical to ordinary bind;
- `next_handle` is valid;
- `next_handle <= capacity`;
- the corresponding slot is unused and inactive;
- fresh sequential handle/slot identity is preserved.

It must populate exactly the same slot state as ordinary bind.

### Bootstrap uniqueness

Production bootstrap replaces the two cumulative prefix scans for:
- `tile_id`;
- `ledger_id`;

with deterministic sort-based uniqueness validation on copied int64 arrays.

Input order is never changed.

### Bootstrap use of fast bind

Only the groundwater production bootstrap may call `bind_prevalidated_fresh`, and only after tile-ID uniqueness has already passed.

## Admission gates

### P0 static/source boundary

- generic `registry%bind` body remains behaviorally unchanged;
- dedicated fast entry point is separately named;
- no caller outside production bootstrap uses it;
- production bootstrap performs global uniqueness before the first fast bind;
- no physical/coupling source changes outside the two bounded runtime modules.

### P1 semantic fail-closed

Must verify:
- duplicate tile ID rejected;
- duplicate ledger ID rejected;
- invalid/unsupported worker count rejected as before;
- ordinary registry duplicate binding remains rejected;
- fresh sequential handles remain 1..N;
- participant tile/handle identity exact;
- no candidate/origin lifecycle change.

### P2 production-shaped performance

Paired canonical baseline versus production candidate:
- N=1,000;
- N=10,000;
- N=40,000.

Frozen admission gates:
- N=1,000 candidate <=1.10 * baseline;
- N=10,000 app-initialize speedup >=3x;
- N=40,000 app-initialize speedup >=8x.

### P3 preservation

At minimum:
- PPA-WU01 production application bootstrap;
- TEMPORAL08 production bootstrap/live semantics;
- MULTI04 1/2/4-worker application-context identity/scaling;
- F-CI110 reconstructed performance admission;
- F-PE-ZERO-WASTE01 poison workspace;
- F-CI canonical qualification.

## No change

No change to:
- Richards equations;
- hydraulic constitutive equations;
- temporal c=0.65 policy;
- BALTOL02;
- nonlinear tolerances;
- retry policy;
- tangent mathematics;
- worker scheduling;
- MODFLOW equations;
- transaction/candidate/ledger/publication ownership.

## Decision rule

Production admission requires all semantic and preservation gates plus the frozen large-N performance gates.

A performance miss is retained as a miss. Do not relax thresholds after observing production-candidate results.
