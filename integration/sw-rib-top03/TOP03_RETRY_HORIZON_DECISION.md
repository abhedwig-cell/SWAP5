# TOP03 unchanged-source retry: partial progress, robust route falsified

The tested source-preserving growth2 retry packet improves progress but is explicitly falsified as a reliable full-horizon remedy. Production TOP03 is not qualified.

## Completed research

Single-interval checkpoint a8e493a3a0e29ac8a863556a4f8d85cf0d74186b:4/14 retry packets complete the same original failed interval at O0 and O2. Uniform8/32 succeed;16/64 fail. A two-piece1/3 partition and adaptive halving/growth2 succeed; adaptive hold-size stops at the1e-6 day floor. Successful packet top-transfer spread is2.009061e-6 cm; storage spread2.316738e-7 cm. All origin preservation and accepted soil/surface/packet mass assertions pass. The surrounding original trajectory remains exactly identical, including its step86 failure. This confirms temporal-partition dependence and prevents treating an accepted prefix as a complete interval.

Full-horizon checkpoint8f09cecac2d26d10a80fe6f4004d981545c99ee7: when a nominal solve fails, retry its complete interval from the original origin, starting at half dt, halve on rejection and double after an accepted solve. Retain original constitutive law, frozen interior K policy, pressure-aware research line search,80/16 bounds,1e-6 day floor and2000 attempts cap. Incomplete packets discard prefix state and exchange. No actual failed solver result is relabelled converged.

| Quantity per build | Result |
| --- | ---: |
| Trajectories | 56 |
| Baseline failures | 30 |
| Retry-rule failures | 20 |
| Repaired full trajectories | 10 |
| Newly failing trajectories | 0 |
| Complete trajectories | 36 |
| No-retry trajectories exactly preserved | 26 |
| Retry packets / complete packets | 33 /13 |
| Retry solves / rejected retry solves | 359 /235 |

Both geometry runners complete O0 and O2:112 full-horizon research integrations. Every numerical summary and retry count matches exactly across optimization levels, excluding CPU. All accepted mass gates pass; maximum aggregate residual6.259438e-13 cm. All previously complete trajectories require no fallback and remain exactly preserved, except refinement-comparison fields whose previous grid may now have a newly complete endpoint. Complete-window top-transfer difference against those baseline trajectories is0 cm.

## Why this is not sufficient

Completion remains nonmonotone under refinement. Shallow dry preponded and ramped histories complete64..2048 nominal steps but fail at4096. Shallow wet preponded completes1024, fails2048, completes4096; shallow wet ramped also has gaps. Deep wet trajectories fail on every64..4096 grid in both histories. Six of eight trajectory families therefore lack a complete finest2048/4096 pair. The two complete deep-dry families have top-transfer differences approximately0.001171 cm (about0.05%); that scoped comparison cannot certify the other six families.

The remaining packet failures reach the inherited minimum duration. The largest trajectory retry count is21, so none could reach the2000-attempt cap. This is not a queued run, missing compiler, mass bookkeeping failure or untested analysis. The nonlinear/source temporal route itself remains unreliable under its declared bounds.

Lowering the floor or choosing whichever grid happens to complete would conceal the issue. Neither is done. This result closes the tested growth2 recipe as a sufficient production remedy, while retaining its partial progress evidence. It does not falsify every possible source-preserving event/branch policy, nor the separately qualified TOP02 hydraulic provider and TOP03 materializer/receipt architecture.

## Production boundary and next useful work

Do not inject this fallback into BASE. An event/branch-aware temporal policy would need an explicit residual and integrated-throughput accuracy contract; a constitutive-law change instead needs qualified B1 reference correction. The branch-local residual gap and the failed cutoff-removal counterfactual remain relevant constraints on either route. Do not spend another broad matrix on undirected Newton/tolerance/floor tuning.

The independent BASE full/half exact-state identity gate still blocks the real converged inundation fixture. Successful real top-active candidate, wrong/correct receipt, replay/stale origin, exactly-once commit and canonical backend reconciliation remain unqualified. These results grant neither that acceptance policy nor canonical admission. No production source changed, no Actions requested, PR#956 stays draft.

Reproduction: `tests/fapp/run_sw_rib_top03_retry.sh` for the shallow packet experiment, then `tests/fapp/analyze_sw_rib_top03_retry.py`. Full horizon: `tests/fapp/run_sw_rib_top03_retry_horizon.sh` with shallow/deep stubs, geometries2/3 and separate RUNNER_TEMP; save `/tmp/top03-retry-horizon-g{2,3}.log`, then `python tests/fapp/analyze_sw_rib_top03_retry_horizon.py`. Exact hashes, complete/prefix classification, refinement sequences and CSV evidence reside in `TOP03_RETRY_RESULT.json`, `TOP03_RETRY_HORIZON_RESULT.json`, `evidence/retry/` and `evidence/retry_horizon/`.
