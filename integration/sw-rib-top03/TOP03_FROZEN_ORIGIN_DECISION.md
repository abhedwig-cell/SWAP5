# TOP03 frozen-origin diagnosis: bounded residual gap established

For one actual failed trial, there is no root of the source-consistent residual on the inspected saturated-upper-node branch with bottom head in[-0.02,0] cm. This is stronger than cutoff/iteration correlation, but deliberately bounded: it does not exclude a global root or a root with other upper-node saturation states.

## Evidence

Checkpoint e2608a343799021b21e37bf3bed3659c6a100019 instruments one unchanged-reference trajectory: consistent shallow four-node geometry, free-drainage bottom7, dry origin profile1, ramped external-head history3,2048 fixed steps over0.25 day. The same trial fails at step86 after85 accepted steps, with80 Newton iterations. O0/O2 reproduce all frozen arrays and trajectory records exactly, excluding CPU. The instrumentation preserves the previously persisted pressure-aware-policy trajectory.

The diagnosis freezes the actual accepted origin water contents and interior face conductivities. It reconstructs all four dumped residual rows from the exact piecewise provider law, with maximum observed reconstruction error0 cm/day. It also checks top/bottom fluxes and provider values against the inherited cutoff oracle. No rejected state is used as an accepted endpoint.

Upper nodes1–3 have positive heads in the inspected branch. Their water contents are therefore theta_s, and their residual rows are linear. Eliminate these rows exactly, including node3's nonzero storage change from its frozen origin. This gives a scalar bottom residual with the original candidate-dependent free-drainage conductivity; it does not freeze or clip that bottom flux.

At the original cutoff near-0.01238604234 cm, the residual is approximately-0.07177364 cm/day on the unsaturated side and+0.10817171 cm/day on the shortcut side. The source limit calculations and bracketing samples are persisted. Thus the residual jumps over zero. Each side is strictly increasing: storage and conductivity are nondecreasing, while the eliminated incoming flux decreases linearly with bottom head. Upper-node heads are affine and positive at both interval endpoints, hence throughout the inspected interval. These facts establish branch-local root exclusion; a sign change across this discontinuity is not a root bracket for bisection.

## Consequence

More Newton iterations, backtracking or a better derivative cannot create a missing root on this branch for this fixed trial. The problem cannot be reduced to tuning the current Newton solve. Conversely, global nonexistence has not been established, so do not label the entire physical problem impossible.

Removing the cutoff is also not a qualified remedy: the separate counterfactual increases failures under both line-search policies. A coherent next route must address the source/reference discretization and near-saturation branch semantics, or a source-preserving temporal retry that demonstrates a solvable accepted interval. Any changed constitutive law needs explicit B1 reference-correction authority and qualification; it cannot enter TOP03 as an incidental numerical repair.

The TOP03 transaction/materializer architecture remains valid in its separately qualified scope. Production remains blocked by this numerical prerequisite and the independent BASE temporal acceptance policy. Live inundation candidate, component receipt/replay/exactly-once qualification and current canonical backend reconciliation are still outstanding. No production source changed, no Actions run, no canonical admission. PR#956 remains draft.

## Reproduction and limits

`RUNNER_TEMP=/tmp/top03-frozen bash tests/fapp/run_sw_rib_top03_frozen_origin.sh tests/fapp/top03_consistent_shallow_stubs.f90 2 > /tmp/top03-frozen.log 2>&1`, then `python tests/fapp/analyze_sw_rib_top03_frozen_origin.py`. The analyzer uses NumPy, persisted baseline trajectory records and frozen coefficients; it implements only the observed near-zero-entry, nonelastic, no-source provider branch. It asserts those assumptions and reconstruction before interpreting results. Exact hashes, frozen arrays, branch-limit calculation and samples reside in `TOP03_FROZEN_ORIGIN_RESULT.json` and `evidence/frozen_origin/`.
