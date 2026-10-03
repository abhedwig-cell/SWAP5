# A28 coupled qualification: bounded FD success, active-window blocker

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

## Admission boundary and next experiment

A28 is not falsified. The active exact predictor gate fails before a meaningful coupled approximate comparison. Therefore no active A28 drift, speed ratio, production runtime gain, worker-local scaling or contention claim is made. FD sensitivity/replay qualification workload timing would not represent a production predictor cost in any event.

The next owning experiment should isolate the derivative's dependence on adaptive temporal partitioning from the same accepted window-18 state. Compare stable prescribed-qbot derivatives under a controlled shared temporal schedule, if an existing qualification seam supports it, and preregister a usable perturbation/conditioning contract before any new active A28 comparison. Do not alter the panel policy or production physics. A field-depth grid with active preferential storage is subsequently required before production-trial admission.

## Reproduction and evidence

Run `bash tests/fpe/run_fpe_a28_fgc45_rfm_coupled.sh`, optionally supplying a validated `LIBMF6` path and `A28_BUILD_DIR`/`A28_EVIDENCE_DIR`. The runner retains build and logs, runs exact then A28 near-equilibrium gates, and stops on the active exact blocker. Expected full-run outcome is currently nonzero at window 18, not PASS.

Evidence bundle: `evidence/PPA_WU05A28_COUPLED_FD_EVIDENCE.json.gz`; manifest: `evidence/PPA_WU05A28_COUPLED_FD_MANIFEST.json`. It includes raw near-equilibrium logs, comparison limits/results, both active exact failures, partial accepted-window results, temporal diagnostic negative findings and local build/check logs. SHA and source-tree identity are explicit. No GitHub Actions were used.

Documentation source checks and strict MkDocs build pass. Existing informational anchor diagnostics remain in the retained build log.
