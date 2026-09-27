# F-PE-SETUP03 — prevalidated sequential registry-bind qualification

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Parent:
`F-PE-SETUP02 / PR #678`

Parent head:
`b1a5afb85a4ca76d7585b85f5e26b1695d370e18`

Branch:
`work/f-pe-setup03-prevalidated-registry-bind`

## Trigger

SETUP02 removed the top-level O(N^2) tile/ledger prefix scans and reduced app initialization from:
- N=10,000: ~0.191 s to ~0.133 s;
- N=40,000: ~3.929 s to ~2.613 s.

The candidate was a real partial gain but failed its frozen advancement gates.

Inspection of `fmr_groundwater_participant_registry_t%bind` identifies a second O(N^2) bootstrap mechanism:

For every participant bind:
1. scan all registry slots for a duplicate tile_id;
2. scan from slot 1 to find the first unused slot.

During fresh production bootstrap both operations duplicate information already known globally:
- SETUP02 validates all tile IDs before binding;
- the registry is newly initialized with capacity N and is filled sequentially once.

## Candidate

Keep the generic registry `bind` behavior unchanged.

Add an explicitly prevalidated bootstrap bind path that is legal only when:
- global tile-ID uniqueness has already passed;
- registry is freshly initialized;
- the next sequential slot is unused;
- handle allocation is still the ordinary next_handle sequence.

The candidate must bind slot `next_handle` directly and skip:
- per-bind duplicate-tile scan;
- per-bind first-unused-slot scan.

All participant state population and handle semantics remain identical.

## P0 semantic requirements

1. Generic `registry%bind` remains byte/behavior unchanged for ordinary callers.
2. Prevalidated path rejects invalid requests exactly as the normal bind path.
3. Fresh sequential handles remain 1..N.
4. tile_id / handle identity is exact.
5. duplicate tile IDs are rejected before entering the prevalidated path.
6. q/tangent checksum after one production-shaped warm trial matches baseline exactly.

## P1 performance

Paired full production bootstrap baseline versus combined candidate:
- SETUP02 scalable global uniqueness validation;
- prevalidated sequential registry bind.

Population:
- N=1,000;
- N=10,000;
- N=40,000.

Five fresh-process repetitions where practical.

Frozen gates:
- N=1,000 candidate <=1.10 * baseline;
- N=10,000 app-initialize speedup >=3.0x;
- N=40,000 app-initialize speedup >=8.0x.

If semantic identity passes but either large-N gate fails, retain measured gain but do not production-admit.

## Production boundary

Research-only compiled source copies.

No production `src/**` admission before qualification.
No physics, tolerances, temporal policy, tangent mathematics, transaction semantics, aggregation order or MODFLOW equations change.
