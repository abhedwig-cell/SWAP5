# F-PE-SCRATCH01 result — persistent application-context trial workspace

Date: 2026-09-27

Status: `CLOSED_LOW_RETURN`

PR:
`#686 — F-PE-SCRATCH01: persistent application-context trial workspace`

Measured head:
`312736275938d1658dc0b10a2ebeb49dd7425ea1`

## Candidate

Move the N-sized and worker-sized orchestration scratch arrays from per-trial local allocation into persistent application-context storage.

## Results

### N=1,000
- worker=4 speedup: 1.0077x;
- no-regression gate: PASS.

### N=10,000
- worker=4 speedup: 1.0479x;
- frozen >=1.05x gate: narrowly FAIL.

### N=40,000
- worker=4 speedup: 1.0007x;
- frozen >=1.08x gate: FAIL.

Exact q and tangent checksums were preserved.

## Decision

Persistent orchestration scratch does not produce a material robust large-N gain.

Do not production-admit this candidate.

The next bounded orchestration hypothesis is caching the origin-dependent worker schedule within one captured application context.
