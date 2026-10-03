# A28 coupled qualification: active paired comparison retained as component-only

Date: 2026-10-03. Decision: **RETAIN_AS_COMPONENT_ONLY_CANDIDATE**.

## Authority and postimage

Baseline admission branch HEAD: `b60449cc4193fcca1f01f1ee9ca42e60ffe46898`.
A28 component admission authority remains `PPA_WU05A28_ADMISSION_CANDIDATE.md` and `PPA_WU05A28_ADMISSION_STATUS.json`; this work does not reopen constitutive/Q4/Q4B qualification or change A28_V1.

Qualification source commit: `c8140b7d4b824df2101460530439f98008380eee` on `work/a28-rfm-fd-qualification`. Source tree: `a4aac5df1fab9d4da77249415fc3f6f9ebbad164`. Local tested commit `8f8008c0` has the identical complete source tree. Connector persistence was used because git push lacked credentials. Canonical HEAD observed separately: `b0d2cc0ac749e1fa60ba4f5f610d01fc0b3b6ad9`; no canonical admission or current-canonical preservation claim is made.

Owning scope VQ/RT: qualification fixtures and documentation only. No production source changes. Checkpoint/candidate/committed-state ownership, lower-face datum/sign semantics, conservative aggregation and publication order are preserved. The explicit bridge is not a production adapter.

## Fixture reconciliation

The inherited generator had retained an analytic direction request in its FD predictor. The explicit fixture disables it. It also replaces center-node hydraulic head with the existing prescribed-qbot Darcy lower-face materializer, including the half-cell q/K contribution. Original accepted face and unperturbed terminal face are used for response assembly; the perturbed heads determine only the derivative.

The inherited endpoint index 6 exceeded the actual four-node FGC45 test grid. Bounds-checked execution caught this. Geometry now derives endpoint depths and contact thickness from actual nodes 3/4. The grid is only approximately 3 cm deep and must not be described as a representative field column.

MODEL_CERTIFICATE cannot supply the required temporal history for this RFM carrier. Its nine unavailable-certificate rejections were fixture incompatibility, not a solver or A28 failure. The supported external full/half route uses the existing 1e-5 cm head budget. These findings are distinct from F-TEMP-MODE3-01. No dynamic-top lifetime hypothesis was reopened.

## Bounded centered-FD qualification

Two exact-RFM accepted lineages, q=1e-6 cm/day, dt=1e-4 day, zero surface supply. Delta q=1e-6, 1e-5 and 1e-4 cm/day. Every baseline/plus/minus candidate completes, has matching lineage/revision/window, and is discarded. Full matrix/RFM snapshots and accepted time/revision remain identical; candidate replay is bit-exact.

All these trials have one attempt, zero retries, zero solver and temporal rejections. FD derivative is about 2.93906063 day on both tiles; the three perturbation sizes satisfy the preregistered 0.1% spread gate. Response units are cm/(cm/day)=day. The existing CENTERED_FD composer derives u=dt/derivative (about 3.40244767e-5) and outward-sign q_u. No preferential state enters the coupler.

This qualifies the route only in this bounded near-equilibrium envelope, not throughout active stateful RFM histories.

## Live exact/A28 correctness

The original live FGC45 assertions pass for exact fixed-64 and A28_V1 using MODFLOW 6.8.0. Both take two coupling iterations. Prepared solve, N:1 aggregation, all-tile corrector/preflights, MODFLOW then SWAP then ledger publication, one revision per tile and one ledger publication per tile pass.

| Quantity | Exact | A28 | Absolute difference |
| --- | ---: | ---: | ---: |
| MODFLOW head, m | -0.71499996773318353 | -0.71499996773318353 | 0 |
| q1, m/s | -1.2815031957413437e-13 | -1.2815031957413437e-13 | 0 |
| q2, m/s | -1.2815031957413437e-13 | -1.2815031957413437e-13 | 0 |
| Weighted q, m/s | -1.2815031957413437e-13 | -1.2815031957413437e-13 | 0 |
| Coupling residual, m/s | 5.1656210172275021e-19 | 5.1656210172275021e-19 | 0 |
| Matrix storage per tile, cm | 1.0430631536566846 | 1.0430631536566846 | 0 |
| RFM storage per tile, cm | 0 | 0 | 0 |

Both tile ledger exchanges also compare identically under the frozen limits. Exact/A28 differ only by the runtime-selected panel policy. Crucial negative control: instrumentation records **zero sorptivity evaluations and zero panels in both variants**. This is a coupling correctness gate, not evidence of active approximate performance or hydrological equivalence under approximation.

## Active exact multi-window falsification

Frozen second fixture: initial surface pressure head -10 cm, dt=0.001 day, rainfall 1 cm/day for four windows then zero for four, intended 64 windows. No active A28 run was permitted before this exact gate.

The original eight-retry limit exhausts capacity while head full/half error decreases from 0.0482532 to 3.15555e-5 cm at dt/256. Other temporal contributions are zero. A preregistered exact-only capacity addendum raises only max retries to 12 and max committed substeps to 4096; all numerical tolerances and forcing remain fixed.

The enlarged-capacity exact sequence completes and publishes **17 live windows**, then fails the FD stability gate while preparing window 18, at t0=0.017 day. The complete trajectory reproduces the same failure in a second run. Ordinary RFM plus/minus trajectories, candidate provenance, accepted-state immutability, discard and replay all pass. Maximum observed predictor whole-window mass residual is 5.131379645756498e-15 cm. No predictor solver rejections occur; temporal retries are numerous.

At tile 2 in the failing window:

| Delta q, cm/day | dH/dq, day | Attempts per sample | Temporal retries |
| --- | ---: | ---: | ---: |
| 1e-6 | 0.92699803250217983 | 554 | 469 |
| 1e-5 | 0.9269979862544518 | 554 | 469 |
| 1e-4 | 0.9354051648709227 | plus 559, minus 554 | plus 473, minus 469 |

Relative spread is 0.009069252297343396, or **0.906925%**, versus the frozen 0.1% limit. The larger positive perturbation also changes adaptive temporal partitioning. This is evidence consistent with derivative sensitivity to adaptive execution; it does not yet prove a unique causal mechanism or invalidate all possible centered-FD choices. No tolerance or delta was changed to turn this negative gate green.

Window 17 final head is -0.06318599858287549 m; residual -1.2925094117835083e-18 m/s; eight coupling iterations. Tile matrix storage is about 1.25593033 cm, RFM storage remains zero. Thus this tiny rainfall fixture exercises matrix/surface response but still does not qualify substantial preferential storage or field-scale RFM.

## Active exact/A28 24-window paired follow-up

The first active exact gate above remains a retained FAIL for its original delta set [1e-6, 1e-5, 1e-4] cm/day. The same-state diagnostic established a local range through 1e-5 cm/day, and the separately preregistered follow-up gate froze [1e-7, 1e-6, 1e-5] cm/day with the 1e-6 derivative used for response composition. Under that narrower contract, exact fixed-64 completed all 24 exact windows and passed its FD stability, candidate/replay, coupling, and publication checks. Only after that exact gate passed was the identical fixture run with A28_V1; it too completed and published all 24 windows.

The runs use the same tiny four-node, two-tile cell, forcing, initial state, MODFLOW 6.8.0 prepared solve, and coupling tolerances. Per-window final results are in the evidence bundle. Both have 8–9 coupling iterations and maximum absolute coupling residuals 2.74594e-17 and 2.73085e-17 m/s (exact and A28). Across the centered-FD samples, both variants complete 672/672 prescribed-qbot trials and 336/336 two-tile per-window predictor sample checks; there are zero solver rejections or failed trials. Maximum absolute trial mass residual is 5.63e-15 cm exact and 4.81e-15 cm A28. Temporal retries are substantial but match exactly in aggregate (730,408 rejections; maximum 2,092 retries in one trial). The paired comparison uses the existing preregistered absolute gates, not limits fitted to the outcome:

| Quantity | Maximum absolute difference | Frozen limit | Result |
| --- | ---: | ---: | --- |
| MODFLOW head, m | 5.0761e-11 | 1e-12 | FAIL |
| q1, m/s | 9.8715e-15 | 1e-15 | FAIL |
| q2, m/s | 2.3608e-14 | 1e-15 | FAIL |
| Area-weighted q, m/s | 1.8800e-14 | 1e-15 | FAIL |
| Coupling residual, m/s | 4.1891e-19 | 1e-15 | PASS |
| Tile 1 ledger, m | 1.9900e-12 | 1e-12 | FAIL |
| Tile 2 ledger, m | 9.8886e-12 | 1e-12 | FAIL |
| Matrix storage, cm | 4.9913e-10 | 1e-10 | FAIL |
| RFM storage, cm | 0 | 1e-10 | PASS |
| Coupling iterations (A28 worse than exact) | 0 | 0 | PASS |

The exact final head is -0.06304742871567759 m and A28 is -0.06304742876643843 m. Relative to the exact trajectory, maximum head, q, ledger, and matrix-storage differences are small (about 8.1e-10, 2.8e-7, 1.4e-7, and 4.0e-10 respectively), but several frozen absolute gates fail. Do not retune these limits or the A28 policy from this outcome. This is a failed strict equivalence gate with small observed drift, not evidence that A28 itself is unacceptable for every opt-in use.

### A28 activation and bounded timing

Test-build-only counters and CPU timers were reset after SWAP/MODFLOW initialization and immediately before the measured 24-window execution, so exact and A28 scopes align. Exact recorded 3,137,540 sorptivity evaluations, all at 64 panels (200,802,560 panels); A28 recorded the same number at 32 panels (100,401,280 panels). Consumer heads covered -10 to about -5.9921 cm, exercising the 32-panel band only. Neither the 16- nor 64-panel A28 band was exercised. Preferential RFM storage remained zero on this shallow tiny grid.

Measured execution wall time was 126.66 s exact and 78.31 s A28 (ratio 1.617). Sorptivity quadrature CPU time was 96.87 s and 48.48 s. Predictor time was 84.66 s and 52.40 s; corrector/SWAP time 41.88 s and 25.76 s; MODFLOW time 0.077 s and 0.094 s. This workload performs centered-FD sensitivity samples and candidate replay for every coupling window, and runs serially on one tiny cell. The ratio is a bounded qualification-workload measurement only: it is not a production speedup, worker-local scaling, contention, or 100,000-column performance evidence.

## Field-depth exact predictor blocker

After the separate practical-use envelope was preregistered, a test-only 10-node/100-cm grid build completed with `-fcheck=all`. Exact fixed-64 was run first at the frozen initial head `-45 cm`, `dt=0.01 day`, and alternating four-window rainfall blocks of `10 cm/day` and zero. It failed during the first FD sample in tile 1, before any MODFLOW call or coupled window: status 2, 13 attempts, 12 retries, 10 solver rejections and 3 temporal rejections. A28 was not run.

The preregistered no-rain attribution (`same grid/head/dt`, rainfall zero) passed exact predictor initialization on both tiles. Its 28 prescribed-qbot trials all completed in one attempt with zero retries and zero solver/temporal rejections; maximum trial mass residual was `9.1014e-15 cm`. The subsequent preregistered amplitude probe at `1 cm/day` again failed tile 1 initialization (13 attempts, 12 retries, 9 solver rejections, 4 temporal rejections). The stop rule therefore prevented the `3 cm/day` probe. A test-only read of the existing solver observation on repeated exact-only rain-1 and rain-10 inputs returned `solver_status=2` (`SW_SOLVE_RETRY_ADVISED`), route `legacy-reference-retry`, and 16/16 nonlinear iterations with 16 Jacobian builds and linear solves. It reported 56 and 90 backtracking attempts respectively and zero alternative-solver calls. The status mapping in the existing legacy adapter means the solver requested a smaller step; the bounded bridge exhausted all 12 transaction retries without a converged sample. This narrows the immediate blocker to nonlinear convergence/retry exhaustion under the event-active field-depth state, while the exact first internal rejection cause remains unexposed. No tolerance or solver policy was changed.

The attempted one-window no-rain wrapper proceeded through predictor initialization but could not load its configured MODFLOW 6.8.0 shared library because the referenced local file had disappeared from the execution workspace. This is retained as an environment incompletion, not a hydrologic result. A standalone predictor-only probe supplies the valid no-rain predictor evidence; no live coupled no-rain claim is made.

This blocks practical field-depth coupled qualification at the exact-RFM predictor stage. It is neither an A28 failure nor a coupled-drift result. Do not advance to A28, performance, or scale on this field-depth postimage.

## Exact-only timestep-response diagnostic

The registered timestep-response probe held the 100-cm field grid, `-45 cm` initial head, `1 cm/day` rainfall, exact fixed-64, and solver controls fixed. Source inspection confirms this qualification bridge sets 16 maximum nonlinear iterations and 8 backtracking steps; the serialized backend type defaults to 8 and 4 unless the parameter set overrides them. The observed failures therefore reached the configured iteration cap even with test settings above those defaults, but remain evidence for this specific test parameterization only. At the first preregistered level, `dt=0.005 day`, exact predictor initialization again failed tile 1 after 13 attempts and 12 retries (10 solver and 3 temporal rejections). The final solver status was retry-advised at 16/16 nonlinear iterations with 106 backtracking attempts. No plus/minus trial completed and no derivative/response was composed. Per preregistration, this is the stopping result.

A `dt=0.001 day` run was also executed despite the frozen stop-after-first-failure rule. It failed after 13 attempts and 12 retries (13 solver, zero temporal rejections; 16/16 final nonlinear iterations; 87 backtracking attempts). This is recorded as an unregistered exploratory observation only and is excluded from gate evidence. Neither smaller timestep resolves the event-active exact predictor in the observed runs. This supports a bounded exact-RFM predictor convergence/retry blocker; it does not isolate the first internal nonlinear rejection or imply an A28 defect. No further forcing/timestep ladder, A28 run, or live MODFLOW claim is made.

## Admission boundary and next experiment

Decision remains **RETAIN_AS_COMPONENT_ONLY_CANDIDATE**. The RFM-compatible centered-FD response is qualified only for this bounded forcing/geometry and the narrower, explicitly versioned local delta contract. Live exact and A28 coupling each run successfully for 24 windows; active A28 use is proven and produces measurable drift that exceeds the preregistered absolute head/flux/ledger/storage limits. Mass closure and coupled residuals remain small, and coupling iterations do not worsen. Because the paired strict correctness gate fails, performance/scalability qualification is incomplete and production-trial admission is not supported. A28 is not classified FALSIFIED_FOR_COUPLED_USE: the result does not isolate the observed tiny drift as an unacceptable A28-specific hydrologic defect across representative RFM storage states.

The follow-up separates strict mathematical-equivalence diagnostics from the practical opt-in approximate-mode decision. The [PPA-WU05A28 coupled practical preregistration](PPA_WU05A28_COUPLED_PRACTICAL_PREREGISTRATION.md) freezes a distinct 2% envelope and the field-depth experiment, without reclassifying the earlier paired run. The field-depth exact predictor now fails under active rainfall while the no-rain predictor initialization passes. The registered timestep-response probe failed at its first level (0.005 day); a second, unregistered 0.001-day observation also failed and is excluded from gate evidence. Stop field-depth forcing experiments under this preregistration. Resume the practical paired fixture only after exact active-event predictor initialization and all exact coupled windows pass; then require nonzero preferential storage and the frozen panel-band activity checks. Performance and scale remain blocked. Keep all original strict failures and this exact-RFM blocker in the evidence record.

## Reproduction and evidence

For the completed active paired follow-up, build the local instrumented qualification library and run both variants with the same 24-window input (supply a validated MODFLOW 6.8.0 `LIBMF6`):

```bash
python3 tests/fpe/build_fpe_a28_coupled_local.py /tmp/a28-coupled-build
export FGC45_MULTISWAP_LIB=/tmp/a28-coupled-build/libfgc45_multiswap.so
export LIBMF6=/path/to/modflow-6.8.0/libmf6.so
A28_RESULT=/tmp/exact-24.json python3 tests/fpe/test_fpe_a28_coupled_windows.py exact 24 > /tmp/exact-24.log 2>&1
A28_RESULT=/tmp/a28-24.json python3 tests/fpe/test_fpe_a28_coupled_windows.py a28 24 > /tmp/a28-24.log 2>&1
python3 tests/fpe/compare_fpe_a28_coupled.py /tmp/exact-24.json /tmp/a28-24.json
```

The original convenience runner still exercises its 64-window sequence and retains the earlier original-delta negative finding; it is not the reproduction command for the separately frozen narrow-delta 24-window follow-up. All logs and JSON outputs from the reported paired run are in the evidence bundle.

Evidence bundle: `evidence/PPA_WU05A28_COUPLED_FD_EVIDENCE.json.gz`; manifest: `evidence/PPA_WU05A28_COUPLED_FD_MANIFEST.json`. It includes raw near-equilibrium logs, comparison limits/results, both active exact failures, partial accepted-window results, temporal diagnostic negative findings, both complete aligned 24-window active logs/results, the paired comparison, field-depth exact predictor and timestep diagnostics (including the explicitly unregistered run), and local build/check logs. SHA and source-tree identity are explicit. No GitHub Actions were used.

Documentation source checks and strict MkDocs build pass. Existing informational anchor diagnostics remain in the retained build log.

## Follow-up diagnostic result

The retained first active run shows an important pattern: the 1e-6 and 1e-5 derivatives at the failed tile differ by about 0.00005%, while 1e-4 differs by 0.907%. The larger plus trial uses five more attempts/retries than its minus counterpart (559/473 versus 554/469). This suggests finite-difference truncation/nonlinearity, adaptive-partition response, or both; current evidence cannot separate them. A preregistered same-state delta ladder is being run as a diagnostic. It cannot retroactively satisfy the frozen gate.

### Narrow-delta exact-only follow-up

At the same accepted window-18 state, delta [1e-7, 3e-7, 1e-6, 3e-6, 1e-5] derivatives span 0.9269978685 to 0.9269993627 day, about 0.000161%. At 3e-5 the derivative is 0.9550106177 day, about 3.02% above the 1e-5 value, and the positive solve changes from 554 attempts/469 retries to 559/473; the negative solve stays 554/469. The 1e-4 derivative is 0.9354051649 day (0.907% above) with the same partition asymmetry. This supports a localized response range while showing that a broader centered perturbation is not locally linear under this execution policy. The 24-window follow-up uses a separate frozen gate and retains this original failure.

The subsequent frozen 24-window pair is fully retained as `a28-aligned-exact-24.*` and `a28-aligned-approx-24.*` in the evidence archive. Both exact and A28 complete 24/24 windows; the old comparison limits report FAIL for head, q1/q2/weighted q, both ledgers, and matrix storage. Counters were reset at the measured-window boundary, proving the panel reduction was active over the same live windows.
