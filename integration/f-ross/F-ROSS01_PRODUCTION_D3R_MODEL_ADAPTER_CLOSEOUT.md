# F-ROSS01 production D3R model adapter closeout

Status: `CLOSED_PRODUCTION_ADAPTER_CAPABILITY`

## Scope

This capability materializes the already-qualified restricted F-ROSS01 D3R duration semantics at the production canonical-model boundary. It does not introduce RossFast physics and does not alter the generic canonical runtime or transaction core.

## Base and production delta

- capability base: `455d2905a9a450ee25ed742d930428a8eefc04bf`
- base authority: closed canonical K_RUNTIME production transaction-window selector
- tested head: `de40b05ab3a701e0762266e1c1afb22a9dc6f740`
- production file added: `src/runtime/mod_rossfast_d3r_model_adapter.f90`
- generic runtime delta: none
- transaction-core delta: none

Pre-closeout compare `455d2905...de40b05` is `ahead_by=4`, `behind_by=0`; the capability consists only of the production adapter, its targeted runtime test, runner and workflow.

## Inherited scientific/numerical authority

Restricted D3R authority is inherited from `work/f-ross01-d3r-bounded-duration-retry-ladder-qualification`:

- post-closeout authority head: `c8dc52dc92d32d075fa3fc57916e8bffb33c14e3`
- authority tree: `8fbe703005fa7d3d8e3dd477312808e07c6251b7`
- D3R adapter blob: `9ccf97ef515ddd63430c8a5bcab6503ca2574f0a`
- frozen D2 base blob: `3cb579554f0931dc41ce05e92e2e7a5f06bf8888`
- initial admitted duration: `0.0016 day`
- retry scale: `0.5`
- canonical max retries: `8`
- admitted solver-duration ladder: `0.0016 / 2^k`, `k=0..9`
- endpoint representation tolerance: `2 ULP`
- restricted hard mass gate inherited from D2/D3R evidence: `1e-12 cm`

## Production contract

`rossfast_d3r_model_adapter_t` is an abstract production-facing canonical model base. It:

1. overrides only `select_transaction_window`;
2. selects the largest currently admissible D3R ladder window without overshooting the outer endpoint;
3. snaps an outer endpoint to an admitted ladder endpoint within the inherited 2-ULP representation tolerance;
4. returns no progress for a residual smaller than the minimum admitted duration that is not an admitted endpoint, causing the canonical runtime to reject fail-closed before a physical trial;
5. exposes `apply_rossfast_d3r_retry_policy`, binding the existing transaction policy to retry scale `0.5` and max retries `8`.

The physical `prepare_interval`, `advance`, storage and temporal-certificate semantics remain deferred to a concrete RossFast model.

## Qualification

Workflow: `.github/workflows/f-ross01-production-d3r-model-adapter.yml`

- GitHub Actions run: `34884354393`
- job: `104111161602`
- tested head: `de40b05ab3a701e0762266e1c1afb22a9dc6f740`
- conclusion: `success`
- O0/O2 output comparison: byte-identical
- output SHA-256: `afb58385cd26832076bd38c0b92bf9c39c6f4a82c3512201764e53b1edb9fdae`

The qualification executes the real canonical interval runtime and the real transaction reference core. It verifies:

- policy defaults `retry_scale=0.5`, `max_retries=8`;
- ladder endpoints for indices 0, 1 and 9;
- composition of `0.004 day` as three accepted D3R transaction windows with exactly one external commit;
- a real solver-rejection path in which three `0.0016 day` attempts are retried and accepted at `0.0008 day`;
- mass residual zero for the deterministic qualification model;
- an unrepresentable sub-minimum remainder fails closed before any transaction call or external commit.

The only compiler warnings in the run are the already-known exact REAL comparisons in `mod_transaction_reference.f90` and `mod_canonical_interval_runtime.f90`; those support files are locally compiled with `-Wno-error=compare-reals`. The new adapter and qualification test compile under `-Werror` without warning exceptions.

## Decision

`ADMIT_PRODUCTION_ADAPTER_CONTRACT`

The restricted D3R transaction-window and retry-policy semantics are now materialized behind the generic K_RUNTIME hook without contaminating the generic runtime with RossFast-specific policy.

## Hard nonclaims

This closeout does **not** claim:

- a concrete production RossFast hydraulic model is admitted;
- D2/D3R research physics have been promoted wholesale to production;
- unrestricted materials, boundary conditions, process coupling or time horizons are qualified;
- arbitrary outer remainders below the minimum D3R ladder duration are supported;
- full SWAP4.3.1 or B1.10 physical equivalence;
- new scientific semantics beyond the inherited restricted D3R authority.
