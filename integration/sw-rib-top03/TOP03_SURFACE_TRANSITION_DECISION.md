# TOP03 surface transition diagnosis decision

## Tested result

The user's surface-switching hypothesis is relevant but is not a sufficient explanation or repair for the current blocker. The 702 trajectories per O0/O2 build agree exactly excluding CPU time. Every individual accepted soil/surface balance passed; maximum aggregate residual is 1.892e-13 cm. Research only: no production source, candidate, component receipt or commit changed or exercised. No Actions run started.

Already ponded constant-head histories have 33 incomplete grids; abrupt imposition from zero pond has the same 33 incomplete grids, all free drainage. All provider evaluations in these 66 failed trajectories retain the external-head regime with zero within-solve and accepted inter-step type switches. Switching is therefore not a necessary cause of those failures.

The 234 matched constant/abrupt pairs have identical solve status, accepted research progress and nonlinear iteration counts. Where progress exists, starting without local pond changes external supply by exactly 0.02 cm, as required by the extra surface storage. It does not change the soil solve. This confirms that pond establishment is correctly distinguished from soil transport in these tests; a soil-only ledger would miss that supply.

All 156 saturated steady/pond-establishment analytical controls pass: soil top and bottom transport equal -4.75 * 0.25 = -1.1875 cm; already ponded storage is unchanged, while abrupt pond establishment adds 0.02 cm and requires signed external transfer -1.2075 cm.

## Where the observed switching actually occurs

The rising-head history does produce real inter-step flux-to-head transitions once the strict sill threshold is crossed. It has 43 incomplete grids rather than 33. In ten initially saturated cases it introduces a failure where the constant-head control completes. Rising head is a different physical forcing, not evidence that smoothing the original forcing is a repair.

Twenty rising-head trajectories also show two within-solve type changes each. These occur on the FIRST substep in initially saturated profiles with lower modes 2 or 7, before external flooding is active. The observed sequence is flux -> atmospheric-head -> flux. It is not repeated switching around the external sill inside Newton. Some such trajectories complete (mode 2); others later fail (mode 7). Two changes alone should not be described as persistent chatter.

The diagnostic provider sees extremely negative trial heads during these changes. For the shallow 4096-step saturated case the switch to atmospheric head occurs at approximately -1.5833334e7 cm; the return to flux occurs at approximately -1.9547324e5 cm. For the deep counterpart the values are approximately -4.75032e5 and -1.58344e5 cm. These are intermediate solver evaluations, not accepted soil states or physical hydrologic excursions. Accepted flux/receipt must never be taken from them.

Source inspection shows the MvG saturated capacity floor C = dt * 1e-7. Thus C/dt at saturation remains a tiny numerical regularizer. The huge trial heads are consistent with an inadequately constrained Newton proposal while draining a saturated origin under zero top supply. This is an inference, not a proven single defect or permission to change storage physics. Instrumentation of the actual Newton proposal/backtracking and saturation constraint is the next discriminating test.

## Route decision

Keep the post-solve transactional exchange architecture. Do not replace accepted interval exchange with Newton-provider flux. Do not silently add hysteresis, smooth external forcing, change lower mode, adjust elastic storage or loosen acceptance.

Separate three issues:

1. Physical boundary activation at the external sill: endpoint sampling must be explicit and eventually event-resolved; coarse grids can jump directly to the final external head and omit the rising-head episode.
2. Saturation/unsaturation with very small pressure-storage derivative: safeguard and inspect nonlinear trial proposals while preserving the original residual and mass owner.
3. Complete-window temporal accuracy: final soil state alone misses transport; the tested linear time-budget allocation also fails and remains unadmitted.

The bounded hypothesis that gradual head forcing removes the convergence problem is falsified. General rainfall/pond/runoff active-set behavior is not qualified here. The next numerical research should target safeguarded proposal/globalization and the boundary active set, rather than tuning only temporal tolerance. Any production shared-policy change requires its existing owner/contract and preservation evidence.

## Evidence and reproduction

Preregistration: `TOP03_SURFACE_TRANSITION_PREREGISTRATION.md`, checkpoint 69b73e9cfd8187c3c1d2f327f0aebde2491b2f14. Final additions only label actual regime-change evaluations; controller/physical equations are unchanged. Result and final source hashes: `TOP03_SURFACE_TRANSITION_RESULT.json`. Raw records, nonlinear stops and actual switch traces: `evidence/surface_transition/`.

```sh
RUNNER_TEMP=/tmp/top03-surface-g2 bash tests/fapp/run_sw_rib_top03_surface_transition.sh tests/fapp/top03_consistent_shallow_stubs.f90 2 > /tmp/top03-surface-g2b.log 2>&1
RUNNER_TEMP=/tmp/top03-surface-g3 bash tests/fapp/run_sw_rib_top03_surface_transition.sh tests/fapp/top03_deep_column_stubs.f90 3 > /tmp/top03-surface-g3b.log 2>&1
python tests/fapp/analyze_sw_rib_top03_surface_transition.py --logdir /tmp
```

GNU Fortran 13.3, O0/O2, runtime bounds/checks and floating-point traps. PR #956 remains draft; production admission remains false. No claim of a live Ribasim geometry or time-varying forcing contract.
