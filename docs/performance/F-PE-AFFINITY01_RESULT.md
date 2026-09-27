# F-PE-AFFINITY01 result — OpenMP placement qualification

Date: 2026-09-27

Status: `CLOSED_NO_AFFINITY_CANDIDATE`

PR:
`#694 — F-PE-AFFINITY01: OpenMP placement qualification`

Measured head:
`7e8fb0308c88bf907a3eddbdff55466a45db212a`

## Host

GitHub Actions host:
- AMD EPYC 9V74;
- 2 physical cores;
- 4 logical CPUs via SMT2.

## Results at N=10,000

### DEFAULT
- worker=1: 0.601183065 s;
- worker=4: 0.225081649 s.

### SPREAD_THREADS
- worker=4: 0.230006234 s;
- relative to default: 0.978589x.

### CLOSE_THREADS
- worker=4: 0.228746671 s;
- relative to default: 0.983978x.
- 2-worker scaling also degraded strongly under this placement.

### SPREAD_CORES
- worker=4: 0.231197504 s;
- relative to default: 0.973547x.

### CLOSE_CORES
- worker=4: 0.233735608 s;
- relative to default: 0.962975x.

All variants preserved exact q and tangent checksums.

## Decision

No explicit OpenMP placement policy improves the current worker=4 production-shaped workload.

The default runtime placement is the fastest measured option on this host.

Do not add OMP placement requirements from AFFINITY01 evidence.
