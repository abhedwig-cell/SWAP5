# PPA-WU05-A6 qualification result — source-rate migration

Date: 2026-09-30

Status: QUALIFIED_SOURCE_RATE_MIGRATION_COMPLETE_SINGLE_COLUMN

Qualified head: 947ffd03082da913dc709699896fb6779dbbb614

Workflow run: 36776134097

## Qualified rate generators

A6 replaces the A5 precomputed research receipts with typed source-bound generators for:

- SWABS=1 sorptivity absorption;
- Darcy-versus-sorptivity unsaturated winner selection;
- saturated matrix/macropore SATFLOW;
- saturated interflow source composition;
- multi-compartment rapid drainage;
- standard-route top inflow limitation and cross-domain redistribution;
- source-bound outflow limitation;
- distributed sorptivity-history candidate update;
- corrected accepted vertical macropore flux reconstruction.

## Important source clarification

QInIntSat is saturated interflow from a perched/top saturated matrix zone, not macropore-domain-to-domain exchange.

The same typed SATFLOW evaluator is therefore reused with different matrix-zone authority.

## Source-rate bundle

A typed A6 bundle now evaluates source rates in one composed route and returns:

- accepted top vertical/lateral receipts;
- returned surface receipt;
- domain/compartment unsaturated outflow;
- saturated macro->matrix outflow;
- perched/main saturated matrix->macro inflow;
- net QExc-to-matrix field;
- rapid-drain compartment outflow.

The standard source limiters are applied before final QExc/rapid receipts are exposed.

## Event-memory semantics

Rate evaluation does not mutate accepted sorptivity history.

Candidate SorpDmCp, ThtSrpRefDmCp and TimAbsCumDmCp are updated or reset only after the selected route is known, using the full source geometry factors including wall wet fraction and domain proportion.

## Accepted vertical fluxes

Accepted vertical macropore faces are reconstructed using the corrected A3 universal local-conservation identity rather than the undefined/inconsistent historical icgwl split.

This preserves local and whole-domain mass across moving saturation interfaces.

## End-to-end replay

The closure test executes:

source rates -> A5 multi-domain candidate -> sorptivity history update -> corrected vertical faces -> seven-field restart -> restored geometry -> next source rates -> next candidate.

The restored route reproduces:

- continuation state;
- derived geometry;
- QExc field;
- rapid-drain receipts;
- accepted top receipts;
- next composed candidate.

## Qualification evidence

Run 36776134097 on head 947ffd03... passed on O0 and O2 with markers:

- PPA_WU05A6_SORPTIVITY_RATE=PASS
- PPA_WU05A6_UNSAT_ABSORPTION=PASS
- PPA_WU05A6_SATURATED_EXCHANGE=PASS
- PPA_WU05A6_SATURATED_SOURCES=PASS
- PPA_WU05A6_RAPID_DRAIN=PASS
- PPA_WU05A6_TOP_INFLOW_LIMITER=PASS
- PPA_WU05A6_VERTICAL_FLUX_RECONSTRUCTION=PASS
- PPA_WU05A6_SORPTIVITY_HISTORY=PASS
- PPA_WU05A6_RATE_BUNDLE=PASS
- PPA_WU05A6_SOURCE_RATE_REPLAY=PASS
- PPA_WU05A6_R1A_GATE=PASS

## Decision

QUALIFIED_SOURCE_RATE_MIGRATION_COMPLETE_SINGLE_COLUMN.

No new continuation state was required.

No mass-ownership falsification occurred.

No production route is activated by A6.

## Remaining work

The next phase is production shaping/integration review, not new source-rate research.

It must:

1. move the qualified research components behind a production-shaped macropore interface;
2. reconcile with current Status-A architecture and exact production solver contracts;
3. preserve strict/reference and practical max-three coupling policies explicitly;
4. qualify inactive-option preservation;
5. qualify restart and transaction behavior in the production-shaped runtime;
6. only then consider canonical admission.