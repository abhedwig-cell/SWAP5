# F-PE-CODEGEN01 closeout

Date: 2026-09-27

Status: `CLOSED_NO_CODEGEN_CANDIDATE`

Compiler/code-generation changes do not provide material end-to-end speedup on the production-shaped MultiSWAP workload.

Best measured worker=4 candidate:
- `-O3 -march=native`;
- about 1.01x versus O2.

This is far below the frozen 1.05x advancement threshold and is host-specific.

No production source or build-policy change is authorized.

Recommended next direction:
large-N runtime allocation / aggregation overhead in the groundwater application context.
