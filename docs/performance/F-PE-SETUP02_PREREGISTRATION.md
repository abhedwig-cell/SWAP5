# F-PE-SETUP02 — scalable uniqueness-validation qualification

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Parent:
`F-PE-SETUP01 / PR #676`

Parent head:
`25e1640dd8bc14ba7c35ec5f83f0f4d4b336fa23`

Branch:
`work/f-pe-setup02-linear-uniqueness`

## Trigger

SETUP01 measured production bootstrap initialization at:
- N=1,000: ~0.00595 s;
- N=10,000: ~0.18866 s;
- N=40,000: ~4.67591 s.

The bootstrap path is strongly superlinear and owns about 73% of N=40,000 setup through warm-up.

Code inspection identified two cumulative prefix uniqueness scans:
- tile_id uniqueness;
- groundwater ledger_id uniqueness.

Each uses `any(config%tiles(1:i-1)%... == current)`, yielding O(N^2) comparison work.

## Candidate

Replace only the cumulative prefix uniqueness scans with a generic exact duplicate detector using:
- copy of the int64 identifier vector;
- iterative merge sort;
- one adjacent-equality pass.

Complexity:
- O(N log N) comparisons;
- O(N) temporary storage.

No assumption is made about identifier ordering.

Frozen semantic requirements:
- unique unsorted identifiers remain accepted;
- duplicate tile_id remains rejected;
- duplicate groundwater ledger_id remains rejected;
- status class remains unchanged;
- all other validation ordering/semantics remain unchanged.

## P0 semantic discriminator

Exercise at least:
1. valid monotone IDs;
2. valid deliberately permuted IDs;
3. duplicate tile ID near beginning;
4. duplicate tile ID near end;
5. duplicate ledger ID near beginning;
6. duplicate ledger ID near end.

Baseline and candidate must make identical accept/reject decisions and status codes.

## P1 performance

Paired baseline/candidate production-shaped groundwater bootstrap at:
- N=1,000;
- N=10,000;
- N=40,000.

Five repetitions per arm.

Measure:
- app%initialize wall/CPU time;
- full fixture initialize time;
- q/tangent semantics after one warm trial.

Frozen performance gates:
- N=1,000 candidate <=1.05 * baseline;
- N=10,000 speedup >=2.0x;
- N=40,000 speedup >=5.0x.

The large-N gates are intentionally high because the candidate targets a suspected O(N^2) path.

## Production boundary

Research-only source copies in P0/P1.
No production `src/**` admission until semantic and performance gates pass.
No physics, tolerance, temporal, tangent, transaction, aggregation or MODFLOW semantic change.
