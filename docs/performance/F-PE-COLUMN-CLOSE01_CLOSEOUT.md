# F-PE-COLUMN-CLOSE01 — single-column performance frontier closeout

Date: 2026-09-27

Status: `CLOSED_CURRENT_EXACT_SINGLE_COLUMN_FRONTIER`

Canonical base:
`integration/f-ci-canonical@4ee57d17a3793a58c792d5de9cdd0a38f9e7918a`

Scope:
- close the current exact-preserving single-column SWAP performance search after the post-TEMPORAL08 rebaseline;
- record negative and positive evidence so rejected mechanisms are not repeatedly reopened without new evidence;
- separate per-column algorithmic optimization from MultiSWAP parallel/scaling work;
- make no production source or physics change.

## Evidence chain

### PROFILE07

F-PE-PROFILE07 / PR #658 reprofiled the current c=0.65 production-shaped path.

Robust observations:
- roughly 85-91% of clean repeated application runtime remained in the Reference/transaction backend;
- the clean accepted internal solves already converged in one nonlinear iteration;
- raw tridiagonal linear algebra was small relative to constitutive evaluation;
- the already qualified A2C frontier remained useful, while looser tolerances had previously failed coupled robustness;
- direct-retention remained speed-positive, but did not cover the remaining conductivity path.

PROFILE07 therefore selected HYDTABLE01 as the last concrete constitutive candidate.

### HYDTABLE01

F-PE-HYDTABLE01 / PR #659 tested a bounded shared K(h) and smooth dK/dh representation.

The frozen N=1024 logK/log(-h) table passed the numerical representation gates:
- worst holdout relative K error about 8.88e-5;
- worst holdout relative dK/dh error about 1.32%;
- monotone and nonnegative K;
- analytical fallback at frozen wet/dry boundaries;
- several-fold lower isolated K evaluation cost.

The real Richards solver result was negative:
- 12/12 solves converged;
- nonlinear iteration and backtracking counts were unchanged;
- median candidate/reference runtime ratio = 1.029395;
- 0/12 materially speed-positive cases;
- 11/12 cases more than 2% slower.

Decision retained:
`CLOSED_REJECTED_SOLVER_RUNTIME`.

This rejects conductivity lookup as a standalone exact single-column optimization for the tested Reference solve.

### LIVE01

F-PE-LIVE01 / PR #656 measured the exact trials actually required by difficult live MODFLOW6 coupling.

The frozen live matrix showed:
- 32 exact SWAP trials;
- 52 transaction calls;
- 72 attempts;
- 20 temporal retries;
- 0 solver rejections;
- 236 nonlinear iterations;
- 236 Jacobian builds;
- 380 linear solves.

Fresh directional work was 19.33% of trial cost, below the preregistered 20% primary-successor gate.
Further temporal-floor widening did not reduce retries or runtime materially.

LIVE01 selected direct decomposition of the unavoidable base q/state Richards solve.

### BASE01

F-PE-BASE01 / PR #660 then decomposed that unavoidable exact q/state solve on current production authority.

Measured:
- serialized Reference backend = 80.81% of exact participant trial time;
- forcing = 1.58%;
- participant postprocessing = 17.27%;
- HeadCalc = 40.99% of backend;
- no isolated inner HeadCalc family cleared the 20% aggregate-backend selection gate;
- temporal-indicator/certificate evaluation = 22.16% of backend.

The only candidate that cleared the isolated cost gate was demand-specialized constitutive evaluation inside the temporal indicator.

Paired result:
- q difference = 0;
- retry/nonlinear trajectory unchanged;
- temporal-indicator gain = 10.52%, below the frozen 15% gate;
- serialized-backend gain = 3.88%, above its 3% gate;
- total q/state trial gain = 2.60%.

Because both preregistered gates were required, the candidate was rejected.

Decision retained:
`CLOSED_NO_EXACT_BASE_SOLVE_TARGET`.

## Interpretation

The present evidence does not support another broad exact-preserving single-column optimization campaign.

The main obvious mechanisms have now been either admitted, bounded, or rejected:
- tolerance reduction: qualified to the current practical A2C frontier; looser variants failed robustness;
- temporal retry reduction: c=0.65 admitted; further local widening did not help the live matrix;
- fresh tangent work: measurable but below the primary live-trial selection gate and heavily reused in production-shaped sequences;
- linear algebra: too small to be a principal target;
- conductivity tabulation: microkernel-positive but solver-negative;
- exact base-solve specialization: only 2.60% total q/state trial gain for the selected candidate, below the composed gate;
- solve elimination / response reuse: conditionally large in synthetic repeated-corrector demand, but not justified by the measured live MODFLOW6 request pattern.

This is not a claim that no future single-column speedup is possible.
It is a decision that, on current measured workloads and exact semantics, further search has crossed into low expected return relative to MultiSWAP/system-level work.

## Closure rule

Close the current exact single-column performance line.

Do not open another single-column optimization workunit merely because:
- a microkernel is locally expensive;
- a synthetic workload shows a large conditional gain;
- a different representation is theoretically cheaper;
- a few percent can be obtained without a measured application-level case.

Reopen only when at least one of the following new evidence classes appears:

1. a production-shaped workload demonstrates a new hotspot owning >=15% of unavoidable single-column wall time;
2. a real coupled workload exhibits repeated nonlinear effort, retries or discarded exact solves materially beyond the current live authority;
3. a new solver/constitutive mechanism demonstrates >=10% end-to-end single-column gain on a preregistered holdout while preserving the required physical and transaction semantics;
4. production model scope changes enough that the current workload authority is no longer representative.

These thresholds are governance criteria for reopening research, not production acceptance criteria.

## Performance-program handoff

Performance effort should now preferentially remain in:
- MultiSWAP parallel execution and worker utilization;
- load balancing and batching;
- scaling to realistic many-column counts;
- coupling-level reduction of unnecessary work where live demand supports it;
- memory/data-layout or worker-runtime effects that appear only at large N.

The production-admitted MULTI04 evidence already shows that this system-level direction is material:
- N=1000, 2 workers: 1.955203x;
- N=1000, 4 workers: 2.698473x.

That is a materially larger current opportunity than the remaining measured exact per-column candidates.

## Production boundary

COLUMN-CLOSE01 is documentation/governance only.

It changes:
- no `src/**`;
- no Richards equations;
- no constitutive equations;
- no tolerances;
- no temporal coefficient;
- no retry policy;
- no tangent mathematics;
- no MODFLOW equations;
- no transaction, mass or publication ownership.

## Final decision

`CLOSED_CURRENT_EXACT_SINGLE_COLUMN_FRONTIER`

Single-column performance is not declared mathematically exhausted.
It is closed as an active optimization line until new production-shaped evidence satisfies a reopening criterion.
