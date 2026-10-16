# F-PE-TEMPORAL11 result — production admission of demand-directed temporal constitutive evaluation

Date: 2026-09-28

Status: `PRODUCTION_ADMITTED`

Production branch:
`work/f-pe-temporal11-production-admission`

Production source change:
`src/solver/mod_reference_richards_temporal_indicator.f90`

## Performance authority

TEMPORAL10 qualification:
- PR #697;
- workflow run `36355854803`;
- measured head `9b6d330dc7b39176875dbbd10312f1df887454fd`.

Paired production-shaped speedups:
- N=1,000: worker=1 1.0313x, worker=4 1.0462x;
- N=10,000: worker=1 1.0283x, worker=4 1.0503x;
- N=40,000: worker=1 1.0521x, worker=4 1.0502x.

All TEMPORAL10 paired runs preserved exact q and response-tangent checksums.

## Production repair

The admitted source uses demand-directed constitutive evaluation for exactly the certificate quantities consumed:
- base-state conductivity;
- candidate-state water content;
- candidate-state capacity.

For direct-retention, water content and capacity remain separate demand calls so table-backed direct-retention semantics are preserved.

No certificate tolerance, temporal acceptance rule, nonlinear solve, tridiagonal solve count, worker schedule, state ownership or publication semantics changed.

## Admission evidence

TEMPORAL11 workflow run:
`36382310091`

Tested head:
`3f87cec449a0e9c834c5da16263d6dca0a962408`

Production scope guard:
- only `src/solver/mod_reference_richards_temporal_indicator.f90` changed under `src/**`.

Direct-retention certificate oracle:
- O0 PASS;
- O2 PASS;
- O0/O2 semantic identity PASS.

FSI38 independent certificate authority:
- prescribed-qbot 10-case matrix PASS;
- independent Neumann/Dirichlet distinction PASS;
- O0 and O2 oracle PASS;
- mode-5 preservation PASS;
- O0/O2 semantic identity PASS.

Final marker:
`FPE_TEMPORAL11_ADMISSION=PASS`

## Decision

Admit the TEMPORAL10 demand-directed constitutive candidate to production.

Expected representative end-to-end gain on the current production-shaped trial path is approximately 5% at worker=4 for N=10,000-40,000, with exact q/tangent preservation from qualification and certificate-preservation evidence from TEMPORAL11.
