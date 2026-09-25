# F-AHL48 — direct-retention resolution and ownership closeout

Date: 2026-09-25

Status: `CLOSED_RESOLUTION_64_QUALIFIED`

Parent: F-AHL47.

PR: #618.

## Question

What is the lowest direct-retention table resolution that preserves the bounded 12-case Reference solver path and fidelity?

## Matrix authority

Workflow run `36153633982`: PASS.

Tested resolutions:

- 64 intervals per decade;
- 128 intervals per decade;
- 256 intervals per decade.

For each resolution:

- B01, B12, O05, O14;
- wet, mid, dry;
- 12 cases;
- current post-zero-waste Reference solver;
- prescribed-head mode 5;
- same hard fidelity gates as F-AHL47.

Total: 36 solver comparisons.

## Results

All three resolutions passed all 12 cases.

### 64 intervals per decade

- cases: 12/12 PASS;
- maximum |head delta|: ~4.32e-5 cm;
- maximum |theta delta|: ~5.35e-10;
- maximum mass residual: ~1.78e-15;
- Newton/backtracking path drift: 0/12.

### 128 intervals per decade

- cases: 12/12 PASS;
- maximum |head delta|: ~1.05e-6 cm;
- maximum |theta delta|: ~7.25e-11;
- maximum mass residual: ~8.60e-16;
- Newton/backtracking path drift: 0/12.

### 256 intervals per decade

- cases: 12/12 PASS;
- maximum |head delta|: ~1.53e-7 cm;
- maximum |theta delta|: ~1.56e-12;
- maximum mass residual: ~1.33e-15;
- Newton/backtracking path drift: 0/12.

## Decision

64 intervals per decade is the lowest tested resolution and already passes the full bounded solver matrix with exact nonlinear-path preservation.

F-AHL48 therefore freezes:

`DIRECT_RETENTION_RESOLUTION = 64 intervals/decade`

for the next production-shaped ownership qualification.

No scientific reason has been demonstrated to pay the 2x or 4x table-memory cost of 128 or 256 within the currently qualified envelope.

## Memory implication

For theta and C, six decades, double precision:

`2 * 6 * (64+1) * 8 = 6240 bytes`

raw payload per unique hydraulic authority.

This is approximately:

- 6.1 KiB per unique authority;
- 61 MiB only in the pathological case of 10,000 completely unique authorities if duplicated once each;
- far less when hydraulic authorities are shared.

Container/key overhead is additional but small relative to the old 256-resolution payload.

## Ownership conclusion

Current serialized MultiSWAP uses one backend instance that processes columns sequentially and reconfigures hydraulic parameters for each trial.

The appropriate production architecture is therefore not a full table embedded blindly in every column/provider.

The next qualification should use:

1. an exact-key immutable representation owner/cache at bind/setup time;
2. one table per unique initialized hydraulic authority;
3. a solve-time provider that holds a direct reference/handle to immutable theta/C arrays;
4. no registry lookup, hashing, binary search, log transform or cache method dispatch inside candidate evaluation;
5. cache mutation/build outside the hot solve loop;
6. explicit future thread-safety qualification before concurrent mutation is allowed.

This preserves the key F-AHL44 lesson: sharing storage is useful, but shared-registry sampling in the hot path is not.

## Next workunit

`F-AHL49 — immutable direct-retention ownership and bind qualification`

Target:

- prove exact-key authority reuse;
- measure build/bind cost;
- prove zero table duplication for repeated same authority;
- keep solve-time direct indexing equivalent to F-AHL47;
- preserve analytical fallback for unsupported/layered authorities;
- no production admission until application-shaped qualification passes.

## Verdict

`F-AHL48 = CLOSED_PASS_64_INTERVALS_PER_DECADE`
