# F-PE-MULTI05 closeout — high-core scaling research

Date: 2026-09-27

Status: `CLOSED_HOST_CAPACITY_BLOCKED`

PR:
`#670 — F-PE-MULTI05: high-core-count production-groundwater scaling`

## Outcome

MULTI05 successfully established a reusable production-shaped high-worker scaling harness and preserved exact q/tangent semantics across worker counts 1/2/4/8/12/16/24 in research-only builds.

The available GitHub Actions host exposed only:
- 2 physical cores;
- 4 logical CPUs via SMT2.

Therefore the primary high-core question cannot be answered on this host.

Valid non-oversubscribed evidence:
- 1 worker: 0.937739037 s;
- 2 workers: 0.483698245 s, 1.938686x, efficiency 0.969343;
- 4 workers: 0.381951371 s, 2.455127x, efficiency 0.613782.

Oversubscribed 8/12/16/24-worker points remained flat around 2.43-2.45x total speedup and are retained only as oversubscription evidence.

## Interpretation

The current architecture scales very well from one to two workers and still usefully to all four visible logical CPUs.

The host does not provide evidence for or against scaling to 8/12/16/24 real hardware threads.

Oversubscription beyond visible hardware threads provides no measurable benefit for this workload on this runner.

## Decision

Do not change the production worker-count policy from MULTI05 CI evidence.

Production remains:
- worker=1 default;
- worker=2 and worker=4 admitted under the MULTI04 boundary;
- higher counts unsupported/fail-closed.

The next experiment is not another code optimization. It is execution of the frozen MULTI05 harness on a known high-core host, preferably the intended 24-thread machine.

## Re-entry condition

Reopen as soon as a host with at least 8 visible logical CPUs is available.

Use the existing frozen harness without retuning:
- N=10,000;
- workers 1/2/4/8/12/16/24 up to visible hardware concurrency;
- exact q/tangent identity;
- replicated medians;
- explicit oversubscription classification.

If real-core efficiency remains >=0.50 at the highest relevant count, advance extended worker-count production admission.

If it falls below 0.50 before available cores are exhausted, advance worker/runtime efficiency decomposition.

## Production boundary

No production `src/**` files were changed by MULTI05.

No change to physics, tolerances, temporal policy, retry semantics, tangent mathematics, transaction ownership, aggregation order or MODFLOW equations.

## Closure

`CLOSED_HOST_CAPACITY_BLOCKED`

The blocker is external execution capacity, not a negative SWAP scaling result.
