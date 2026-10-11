# F-PE-MULTI04 P2 result — bounded hybrid production scheduling

Date: 2026-09-27

Status: `PASS_BOUNDED_HYBRID_PRODUCTION_SCHEDULING`

PR:
`#666 — F-PE-MULTI04: production application-context worker-local groundwater parallel admission`

Authority:
- exercised head before result documentation: `26353c45d5eee6388264bc1aeecd0be35578ec13`;
- workflow run: `36318282587`;
- job: `p2-hybrid-production-scheduling`;
- job id: `108617039264`;
- harness: `tests/fpe/run_fpe_multi04_p2_hybrid_production_scheduling.sh`.

## Scope

P2 qualifies the production implementation of the frozen MULTI03 scheduler rule inside the real groundwater application-context path.

The production rule is:

1. construct ordinary deterministic static modulo ownership;
2. obtain only immutable pre-trial predecessor-history cost proxies;
3. compute predicted static max/mean worker load;
4. retain STATIC when the ratio is <=1.20;
5. otherwise use deterministic descending-cost least-loaded-bin assignment;
6. execute trials on worker-local mutable Reference backends;
7. retain result storage by canonical tile index;
8. aggregate only afterwards in canonical cell/tile order.

No frozen physical or coupling semantics are changed.

## Frozen mixed-cost authority

Population:
`N=1000`.

Predecessor-history rates:
- 100;
- 400;
- 1600;
- 6400.

Orderings:
- ordering 0: block/geclusterde cost classes, expected 4-worker scheduler = STATIC;
- ordering 1: interleaved adverse modulo placement, expected 4-worker scheduler = COST_AWARE.

The harness also builds a research-only static authority by disabling only the 1.20 switch. Production physics, temporal policy, tangent mathematics and transaction semantics are otherwise identical.

## Qualification result

PASS.

The completed P2 job proves that all frozen exits in the harness were satisfied on the exercised production head:

- q checksum exact identity across worker counts and against static authority;
- tangent checksum exact identity across worker counts and against static authority;
- ordering 0 selected STATIC;
- ordering 1 selected COST_AWARE;
- selected predicted max/mean load <=1.20;
- 2-worker speedup >=1.5x;
- 4-worker speedup >=2.2x;
- selected hybrid runtime <=1.02 * static runtime;
- repeated trial q/tangent checks remained exact within each variant.

No threshold was relaxed.

## Scheduler implementation audit

The production application context:

- initializes worker count 1 as SERIAL;
- computes static modulo owner assignment first;
- obtains `pretrial_cost_proxy` before trial execution;
- switches only when the frozen 1.20 ratio is exceeded;
- uses deterministic cost ordering with canonical tile index as the equal-cost tie-break;
- uses deterministic lowest-index worker resolution for equal worker loads;
- executes each worker's owned tiles on one private mutable backend;
- writes each trial into its canonical tile-index slot;
- performs cell aggregation after the parallel trial phase in canonical order.

This preserves deterministic publication order independently of execution order.

## Decision

P2 closes:

`PASS_BOUNDED_HYBRID_PRODUCTION_SCHEDULING`

The production scheduler is admitted as a candidate for final MULTI04 closure, subject to the live worker-4 MODFLOW6, preservation and closeout gates.
