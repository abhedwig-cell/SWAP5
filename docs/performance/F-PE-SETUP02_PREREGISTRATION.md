# F-PE-SETUP02 — scalable tile/ledger identity uniqueness validation

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Parent:
`F-PE-SETUP01 / PR #677`

Parent head:
`51869b04a25cef431211f0ee03b894973d5d4771`

Branch:
`work/f-pe-setup02-scalable-id-validation`

## Trigger

SETUP01 measured `app%initialize(config)` as the dominant large-N setup cost:
- N=1,000: about 0.0057 s;
- N=10,000: about 0.189 s;
- N=40,000: about 4.707 s.

Code inspection identified two O(N^2) duplicate-detection loops:
- tile_id uniqueness;
- ledger_id uniqueness.

## Candidate

Replace each growing-prefix `any(... == current_id)` scan with deterministic O(N log N) uniqueness validation:

1. copy the int64 identity vector;
2. deterministic merge-sort the copy;
3. reject when any adjacent sorted values are equal.

The input config and production identity values remain unchanged.

## Semantic requirements

The candidate must preserve:
- unique IDs accepted;
- duplicate tile_id rejected;
- duplicate ledger_id rejected;
- all existing validity checks and profile gates;
- fail-closed status behavior;
- deterministic execution.

No physical state or coupling semantics are touched.

## Performance matrix

Paired current/candidate `app%initialize` timing at:
- N=1,000;
- N=10,000;
- N=40,000.

Three fresh-process repetitions per arm.

Frozen gates:
- candidate <=1.05 * baseline at N=1,000;
- candidate >=2x faster at N=10,000;
- candidate >=5x faster at N=40,000;
- semantic duplicate tests pass.

These are research advancement gates, not production admission criteria.

## Production boundary

P0 uses research-only compiled source copies.
No production `src/**` change before qualification.
