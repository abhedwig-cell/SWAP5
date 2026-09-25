# F-AHL48 — direct-retention resolution and ownership closeout

Date: 2026-09-25

Status: `CLOSED_RESOLUTION_64_SHARED_OWNERSHIP_QUALIFIED`

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

## Shared immutable ownership qualification

F-AHL48 then implemented the preregistered ownership architecture as a research provider:

- one immutable 64-resolution theta/C representation per exact initialized hydraulic authority;
- providers retain only a compact integer slot plus the analytical fallback binding;
- bind-time exact-authority lookup/build occurs outside the solve loop;
- candidate evaluation directly indexes `pool(slot)` and performs no authority search;
- an explicit freeze transition prevents creation of unseen authorities once the read-only solve phase starts.

### 10,000-provider ownership gate

Workflow `F-AHL48 shared ownership`: PASS.

Observed after binding 10,000 providers to one authority, then a second authority:

- providers: 10,000;
- unique representation entries: 2;
- representation builds: 2;
- cache hits: 10,000;
- raw theta/C payload: 12,480 bytes for two authorities;
- provider object size: 24 bytes;
- frozen state: true.

Thus 10,000 same-authority providers do not duplicate the 6,240-byte table payload.

At one shared authority, the raw storage order is approximately:

- shared theta/C payload: 6.24 kB;
- 10,000 provider handles: about 240 kB from `storage_size`;
- versus about 62.4 MB if the raw table payload were embedded once per provider.

This is a storage-structure statement, not a full process RSS claim.

### Frozen parallel-read gate

OpenMP read-only qualification after pool freeze: PASS.

- threads: 8;
- repeated concurrent demand evaluations: 20,000;
- maximum deviation from the serial reference: exactly 0 in the test.

No concurrent mutation is permitted by this qualification. The supported concurrency model is:

`build/bind -> freeze -> concurrent immutable reads`.

### Shared-provider solver timing

Single-fixture B01-mid paired timing retained the F-AHL47 gain:

- median candidate/analytical ratio: `0.700326`;
- same 4 Newton iterations;
- same 4 backtracking attempts;
- head delta about 7.3e-9 cm;
- theta delta about 1.0e-10.

A broader 12-case shared-provider timing matrix also passed.

Across B01/B12/O05/O14 × wet/mid/dry:

- fidelity/path gate: 12/12 PASS;
- speed-positive cases: 12/12;
- speed-negative cases: 0/12;
- median candidate/analytical ratio: `0.725178`;
- minimum case median: `0.679213`;
- maximum case median: `0.770338`.

Thus shared immutable ownership does not erase the direct-retention speed benefit.

## Ownership conclusion

The research architecture now satisfies the intended F-AHL48 ownership requirements:

1. 64 intervals per decade is sufficient in the bounded 12-case matrix;
2. table memory scales with unique hydraulic authorities, not column count;
3. solve-time evaluation uses direct slot access without hot-path authority lookup;
4. bind/build mutation can be separated from a frozen read-only execution phase;
5. concurrent frozen reads are qualified in the bounded OpenMP gate;
6. current-postimage solver fidelity and broad speed benefit survive the shared design.

The remaining work is no longer representation research. It is production-shaped extraction and application qualification.

## Next workunit

`F-AHL49 — production-shaped direct-retention extraction and application qualification`

Target:

- extract the 64-resolution shared immutable provider into production modules;
- retain explicit opt-in and analytical default;
- preserve exact-key authority ownership and freeze semantics;
- fail closed for unsupported heterogeneous/layered compositions until separately qualified;
- keep full/K/point-conductivity routes analytical;
- qualify setup/build cost and application-level memory behavior;
- replay the 12-case solver matrix and paired timing on the production-shaped implementation;
- qualify production MultiSWAP application wiring before any admission decision.

No production admission is implied by F-AHL48.

## Verdict

`F-AHL48 = CLOSED_PASS_64_SHARED_IMMUTABLE_OWNERSHIP`
