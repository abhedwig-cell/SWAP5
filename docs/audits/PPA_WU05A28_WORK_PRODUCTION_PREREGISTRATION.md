# A28 Work production decision continuation

Date: 2026-10-04. Status: preregistered bounded continuation, not admission.

Baseline: a96886f6a38a1805056fabe9d61bc59a725f83f4. Local clone clean at entry. Frontier workflow 37184823346 was queued. Existing frontier is executed locally without changing its criteria. Initial local observations: 1e-10 passes; 1e-8 fails aggregate trial mass; 1e-6 and 1e-5 fail completion. Preserve these results. Repeat with observation-only mass-rejection, Jacobian, linear-solve, backtracking and completed-time counters. No relaxation of external mass or temporal gates.

Canonical reconciliation target: fae6d8d3d1687bfb220851f43603ab63d4989a29. Branch is an unadmitted research postimage. Relevant canonical difference includes RFM dynamic-top provider lifetime, temporal error and A28 support. Do not describe branch evidence as canonical production evidence. Preserve branch physics for the controlled experiment; integration requires explicit reconciliation and requalification.

If 1e-10 repeats successfully, use it as a bounded candidate for exact field-depth live coupling, not as a production default. First test exact predictor initialization at the original practical fixture rainfall 10 cm/day. Then run original 24-window exact workload (-45 cm, 100 cm/10 nodes, dt .01 day, alternating four-window rain10/zero blocks) with only internal solver balance tolerances 1e-10; retain all native correctness and activity gates. A28 follows only after exact passes. Original 2% practical criteria and required two A28 panel bands remain frozen. If exact fails, diagnose at the failing accepted checkpoint rather than running A28. Further controlled repair must be registered before execution.

Ownership: qualification bridge/scripts/docs only. Production solver, transaction and coupling semantics held fixed. Committed state immutability, discard/replay, mass conservation, accepted-state publication and solver-policy/physics separation remain controlling invariants. No production admission from fixture results alone.

Performance may proceed only after paired practical correctness; use separately calibrated middle centered delta and repeat timing without build/setup. If correctness fails, record performance as unqualified rather than timing a failed path.

## Causal separation and window-4 failure diagnostic

Source inspection after the first live failure found that the backend passes `max(compartment_balance_tolerance, 2.8e-16)` to `prepare_rfm_live_trial`. That value affects surface admissibility, IC geometry, storage truncation and RFM accounting. The original nominal solver-only frontier is therefore confounded; retain its outcomes without claiming a pure solver cause. Before another frontier run, generate a build-local backend holding this RFM tolerance at the original 1e-12 while varying only the solver compartment/total settings. Repeat the four frozen tolerances. Production source unchanged.

The first live exact 1e-10 run completed three windows and failed predictor sampling for window 4 with 145 solver-class rejections, but final observation solver_executed=false and no HeadCalc budget marker. Accepted RFM storage was zero. Preregister an observation-only generated preparer logging the surface-composition failure status, regime, ponding, runoff, top head, trial duration, event age and preferential supply. Repeat exact rain10 sequence with RFM tolerance separated. Do not add ponded physics, change forcing or weaken correctness. If this diagnoses unsupported ponded surface physics, retain the original fixture failure and explicitly bound the required new capability.

## Partition-aware preflight repair falsification

Separated live repeat fails at t=.0341797463333 day before Richards: surface status REFERENCE_REQUIRED, head regime, positive prospective ponding (down to 1.67117e-9 cm), accepted top head -26.00636 cm, while computed preferential supply is about 5.00706 cm/day. The full incoming rain10 is evaluated as matrix supply before RFM partitions it. This can reject an unponded accepted state even when the partitioned matrix supply has an admissible flux boundary.

Preregister a build-local repair: only when accepted ponding is exactly zero, evaporation is zero, and the failed surface composition specifically requests the reference route with a valid activation, re-evaluate dynamic-top preflight with the computed matrix supply. Restore the original total potential input for RFM partition/accounting and rerun the existing preparer. All existing preflight regimes/ponding checks and mass gates remain active. An actually ponded post-partition preflight still fails. Do not add ponded RFM physics or alter sigma, forcing, storage truncation or accepted state.

Run the frozen exact 24-window workload first. Failure is retained and diagnosed; no A28 until exact native correctness and RFM activity succeed. The original negative runs remain immutable. Generated postimage is research, not production admission. A repaired correctness pass alone does not satisfy head-excursion or nonzero-storage activity, which remain separately required.
