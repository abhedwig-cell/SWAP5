# F-PE-CODEGEN01 result — compiler/code-generation performance frontier

Date: 2026-09-27

Status: `CLOSED_NO_CODEGEN_CANDIDATE`

PR:
`#684 — F-PE-CODEGEN01: compiler/code-generation performance frontier`

Measured head:
`49b281ccd49842780a26f234e6260b961821d649`

Workflow run:
`36353127394`

Host:
- AMD EPYC 9V74;
- 2 physical cores;
- 4 logical CPUs via SMT2;
- GNU Fortran 13.3.0.

## Paired production-shaped results at N=10,000

### BASE_O2

- worker=1: 0.917940426 s;
- worker=4: 0.387213783 s;
- internal 4-worker speedup: 2.370630x.

### O3

- worker=1: 0.926278439 s;
- worker=4: 0.392249199 s;
- versus O2: 0.9910x at worker=1, 0.9872x at worker=4.

### O3_NATIVE

- worker=1: 0.893098796 s;
- worker=4: 0.383559122 s;
- versus O2: 1.0278x at worker=1, 1.0095x at worker=4.

### O3_NATIVE_LTO

- worker=1: 0.909253417 s;
- worker=4: 0.384648378 s;
- versus O2: 1.0096x at worker=1, 1.0067x at worker=4.

All variants preserved exact q and tangent checksums.

## Decision

No candidate reaches the preregistered >=5% worker=4 end-to-end speedup gate.

`-O3` alone is slightly slower than the O2 authority.
Host-specific `-march=native` produces only about 1% worker=4 improvement.
LTO adds no material gain.

Therefore compiler/code-generation tuning is not a worthwhile active performance line on the current workload.

Do not change production compiler policy from CODEGEN01 evidence.
