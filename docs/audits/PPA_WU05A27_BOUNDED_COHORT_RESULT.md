# A27 bounded-cohort research frontier

Date: 2026-10-02. Status: LOCALLY_TESTED_RESEARCH_SCREEN, NOT_PRODUCTION_QUALIFIED.
Code postimage: `8ff6309a7eba98ee9cd66ef79da0bb7c5da0a5a2`.
Canonical reconciled: `27b271c2f3d1ea54e0110f56b73400e3b6935e11`.

## Decision

A fixed limit of 16 cohorts per node passes all 50 preregistered comparisons against exact research mode 7 across the five timestep resolutions. Eight cohorts pass 49/50 and fail the finest Ks1 continuous IC-input case. Recommend mode 9 only as a bounded research continuation candidate. This is not E1 production equivalence, a physically validated closure, or a performance/stability qualification.

The limiting scientific blocker is unchanged: finite contact, frozen event sorptivity, moisture-feedback capacity clipping and dry-reset have not jointly been independently justified as a transient wall-exchange closure. Full production A/B/C, atmospheric forcing regimes, parameter mapping, multi-geometry cases and repeated performance/scaling remain OPEN. Do not integrate this research state into production or reinterpret A26H without a new physical/state contract and central review. Reverse exchange matters in these mechanisms; its necessity in every regime is not established.

## Local evidence

The 500 cases completed with exit 0 and 5,000 sampled records. Both process runners pass O0/O2 equality, including analytic mixed-age uptake, original scalar-history falsifiers, capillary saturation boundary, 20,000-case process screen, geometry/history/replay checks and compression conservation/accepted-origin isolation. The 400 shared column cases reproduce all previously recorded numeric strings exactly, excluding CPU measurements. All interval and whole-column mass guards pass.

| Screen metric, maximum absolute sampled error | 8/node | 16/node | Limit |
| --- | ---: | ---: | ---: |
| Receiver storage, cm | 0.0118726942493 | 0.00312429291740 | 0.01 |
| Cumulative exchange, cm | 0.0118726942493 | 0.00312429291740 | 0.01 |
| Cumulative bottom transfer, cm | 0.00597449935122 | 0.00147637290831 | 0.01 |
| Selected theta, maximum | 0.000605235187954 | 0.000139066341547 | 0.001 |
| Selected pressure head, cm | 0.264041043656 | 0.0606091405686 | 1 |

The failing case is soil/Ks selection 1, state 4, dt=0.000125 day, mode 8. Its receiver and integrated exchange errors exceed 0.01 cm. Thresholds are unchanged. The attached comparison table retains each of the 100 comparisons and all individual observables, not only global maxima. Output is sampled every 0.1 day; this screen does not bound unsampled extrema.

## Refinement and memory limits

Exact-cohort continuous-input receiver differences approximately halve with timestep halving: Ks1 0.00167919, 0.000839341, 0.000419592, 0.000209771 cm; Ks5 0.00187964, 0.000939397, 0.000469623, 0.000234792 cm. These are successive-grid sampled trajectory differences, not errors against a known continuum solution.

Fixed-count compression introduces an independent resolution floor. In Ks1, mode 9's last two refinement differences are 0.000828721 and 0.000966206 cm, so monotonic contraction is NOT established. Passing the finite screen cannot be extended to arbitrarily small dt. Mode 8's finest failure is retained as a negative route finding. The complete refinement table includes other states and selected head/theta observables.

In the finest continuous-input case, exact mode 7 stores 8,000 active intervals and 256,000 nominal packed bytes per column. Modes 8/9 store 8/16 intervals and 256/512 nominal bytes in this case. With ten nodes their general count bounds are 80/160 and packed payload bounds 2,560/5,120 bytes. These exclude descriptors, capacity, candidate copies, allocations and runtime overhead; they are not RSS or measured ensemble memory. Compression preserves geometric coverage and integrated seed, not exact square-root uptake.

Single-run CPU counters remain in raw output. The harness still evaluates unused primitives, timing has no repeats/warmup and no full production comparator is present. No speedup or superior stability claim is made.

## Durable evidence and reproduction

Raw 210/280/400/500 case files and original available logs are retained in a deterministic split gzip tar archive. Concatenate `docs/audits/evidence/PPA_WU05A27_COHORT_EVIDENCE.tar.gz.part-*` in lexical order. Combined SHA256 is `b816cd0920e91905403ac9c437b20b3b3c6b8c6b8b8a5adb40d443c0864ec245`. The archive manifest records each file hash and each run's exact code SHA. Dependency SHA256 values are computed with `git show <that-run-ref>:<path>`, never against modified current sources. Earlier run exit status is inherited from the handoff, with raw files recovered intact; the current 500-case exit was observed directly.

Run `FC=/tmp/top03-bin/gfortran bash research/rfm/a27/run_signed_column.sh`, or supply another compatible compiler. Process checks are `run_wall_cohort.sh` and `run_capillary_budget.sh` in the same directory. Run `python3 research/rfm/a27/analyze_bounded_cohorts.py <raw-column.csv> <output-directory>` for the unchanged thresholds, all comparison failures, memory and refinement tables. The archive and tables preserve relevant sampled trajectories without relying on a plotted summary.

Documentation source checks and strict MkDocs pass; generated site output remains outside the repository. No GitHub Actions run was requested for this research block.

## Canonical delta and ownership

The new LOW05-A delta adds optional prescribed-head control and attempt proposal memory in the serialized backend. None of the research runner's compiled production dependencies changes in that delta. The runner does not compile that backend. Therefore its research dependency identity is preserved, while older serialized preservation is NOT claimed as new-head validation. No canonical merge was performed here; central SWAP5 regie remains the admission owner.

A26 remains canonically admitted and closed as an accepted-state-frozen first-order split. A27's areic source-unit repair remains independently locally qualified for regie review and noncanonical. This block changes no production source, source/sink ABI, top-input owner, MB-deep receipt, restart schema or numerical defaults. Older A11-A26 intermediate records are read as bounded historical authorities under the later A26 closeout, not as current competing status.
