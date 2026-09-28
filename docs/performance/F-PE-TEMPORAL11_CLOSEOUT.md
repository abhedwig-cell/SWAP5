# F-PE-TEMPORAL11 closeout — production demand-directed temporal constitutive evaluation

Date: 2026-09-28

Status: `CLOSED_PRODUCTION_ADMITTED`

## Decision

The TEMPORAL10 candidate is production-admitted.

Representative paired qualification showed about 5% worker=4 end-to-end gain at N=10,000 and N=40,000, with exact q and response-tangent preservation.

TEMPORAL11 added direct production evidence:
- direct-retention certificate oracle at O0 and O2;
- O0/O2 semantic identity;
- FSI38 prescribed-qbot independent certificate oracle;
- mode-5 certificate preservation;
- exact production source scope guard.

## Production change

Only:
`src/solver/mod_reference_richards_temporal_indicator.f90`

The indicator now evaluates only the constitutive quantities it actually consumes:
- base conductivity;
- candidate water content;
- candidate capacity.

Direct-retention θ and C remain separate specialized demand calls.

## Semantic boundary

Unchanged:
- certificate definition;
- temporal budget/acceptance semantics;
- nonlinear trajectory;
- extra tridiagonal solve count;
- mass accounting;
- q/tangent semantics;
- worker scheduling;
- transaction/publication ownership.

## Closure

`CLOSED_PRODUCTION_ADMITTED`
