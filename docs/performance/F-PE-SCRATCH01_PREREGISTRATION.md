# F-PE-SCRATCH01 — persistent application-context trial workspace qualification

Date: 2026-09-27

Status: `PREREGISTERED_RESEARCH_ONLY`

Canonical parent:
`integration/f-ci-canonical@933ea3824c9fbfe74c551d6d6fe8144f39b6c378`

Branch:
`work/f-pe-scratch01-persistent-trial-workspace`

## Trigger

The parallel `application_context_trial_cell_heads` path currently allocates several tile-sized scratch arrays on every trial:
- tile head workspace;
- registry status;
- owner mapping;
- predicted cost;
- order;
- merge workspace;

plus a worker-count-sized load array.

These are orchestration workspaces, not physical state. Their shapes are fixed by the bound application context.

## Candidate

Move the parallel trial scratch arrays into private allocatable components of
`fmr_groundwater_application_context_t`.

Allocate them once during successful context bind when `worker_count > 1`.

Reuse the same arrays for every subsequent trial on that context.

Frozen behavior:
- same owner mapping;
- same static/cost-aware scheduler selection;
- same sort routine;
- same worker-local backends;
- same canonical result storage and aggregation;
- same fail-closed status behavior.

The context is already transactionally mutable during a trial; no new concurrent-call guarantee is introduced.

## Paired qualification

Production-shaped MULTI04 workload:
- N=1,000;
- N=10,000;
- N=40,000.

Five repetitions after warm-up.

Primary:
- worker=4.

Secondary:
- worker=1 remains the unchanged serial authority.

Semantic requirements:
- exact q checksum;
- exact tangent checksum;
- deterministic repeated output;
- identical success/failure outcome.

## Performance gates

Advance only if:
- N=1,000 worker=4 candidate <=1.02 * baseline;
- N=10,000 worker=4 speedup >=1.05x;
- N=40,000 worker=4 speedup >=1.08x.

If the candidate misses either large-N gate, close persistent scratch as low return.

## Production boundary

Research-only compiled source copy.

No production `src/**` change before qualification.
No physics, aggregation, tolerances, temporal policy, tangent mathematics, scheduling decisions, transaction or publication semantics change.
