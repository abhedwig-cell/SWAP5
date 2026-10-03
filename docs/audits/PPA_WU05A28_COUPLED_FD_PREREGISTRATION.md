# A28 coupled FD qualification

Date: 2026-10-03. Baseline: b60449cc4193fcca1f01f1ee9ca42e60ffe46898.
Workstream VQ/RT. Qualification-only explicit FGC45-derived bridge; no production interface or physics mutation.

A28_V1 is frozen. Exact fixed-64 first. Ordinary full RFM prescribed-qbot trajectories must complete without an accepted-trajectory direction request. Baseline q=1e-6 cm/day, centered perturbations 1e-6, 1e-5, 1e-4 cm/day. Each sample is discarded and replayed from the same accepted checkpoint. Full matrix/RFM snapshot bit equality, time/revision equality, candidate provenance and discard readiness are gates. Mass residual and max step residual <=1e-12 cm. Derivative finite, absolute magnitude >1e-8 day, relative spread <=1e-3. Default delta=1e-5 cm/day. Negative flux is permitted by native prescribed-qbot semantics.

Use the existing Darcy lower-face materializer for each terminal trajectory, including q-dependent half-cell head drop and state-dependent conductivity. Center-node hydraulic heads are not interface heads. Baseline terminal head and original accepted lower-face head enter the existing CENTERED_FD response composer. No RFM state is transferred to the coupler.

Live exact correctness must pass the original FGC45 prepared-solve, N:1, publication, ledger and mass gates before A28 comparison. Comparison absolute limits: head 1e-12 m; q1/q2/weighted q 1e-15 m/s; tile exchanges 1e-12 m; coupled residual 1e-15 m/s; accepted storage difference 1e-10 cm. No extra solver rejections/failures allowed. Panel activation and representative multi-window performance are separate mandatory gates. A single tiny window cannot establish speedup or scaling.

If ordinary RFM trials fail, isolate that blocker and stop FD advancement. If exact coupled correctness fails, do not classify A28 as falsified. Retain component-only candidate until predictor/coupled/performance gates are qualified.

## Fixture reconciliation before the FD gate

Bounds-checked execution exposed endpoint index 6 on a four-node grid. RFM geometry now derives endpoint depths/contact thickness from actual nodes (tiles use nodes 3/4). This remains a deliberately tiny correctness grid. Initial FD attempts used MODEL_CERTIFICATE with an RFM carrier, which has no temporal-history certificate service; nine unavailable-certificate rejections do not falsify ordinary RFM solves. Use supported external full/half temporal acceptance with the existing 1e-5 cm HEAD_BUDGET, held identical for exact/A28. Disable accepted-trajectory direction requests in both configurations. No production repair.

## Frozen active window sequence

Additional exact-only correctness characterization uses initial surface head -10 cm, dt=0.001 day, rainfall 1 cm/day for four windows then zero for four, repeated over 64 windows. Geometry and numerical acceptance remain fixed. Same accepted lineage continues across windows. Wet consumer heads exercise 32/16 where actually evaluated; no forcing tuning using A28 output. Failure of this exact fixture is retained. Timings exclude compilation, dependency acquisition and MODFLOW model construction; initialization/predictor qualification is separately reported. Counters and quadrature CPU timing are inserted only in a build-local copy of the production sorptivity source; production files remain unchanged. No worker-local/thread claim follows from these serial counters.

### Exact-only execution capacity addendum

The first wet exact fixture failed at retry limit 8, with zero solver rejections. Build-local temporal diagnostics show the head difference decreasing from 0.0482532 to 3.15555e-5 cm at dt/256; other temporal contributions are zero. This is not a missing RFM temporal contract. Before any active A28 run, increase only finite execution capacity to 12 retries and 4096 committed substeps, retaining mass/head/temporal tolerances, policy, forcing and window. The original exhausted-capacity result is retained. If finite capacity remains insufficient, stop active FD qualification rather than relaxing numerical tolerances.
