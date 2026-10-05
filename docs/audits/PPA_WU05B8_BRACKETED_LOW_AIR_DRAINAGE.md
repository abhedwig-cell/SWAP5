# PPA-WU05B8 bracketed low-air drainage composition

Status: implemented candidate; runtime trajectory qualification in progress. It is not canonically admitted.

The optional `frost_low_air_drainage` carrier supplies finite negative physical drain depths and requires the admitted `frost_drainage` option with its explicit positive head/temperature budgets. It does not infer physical drain depths from hydraulic outlet heads. Ordinary Reference mode2, rootless prescribed signed nodal drainage is the bounded execution surface.

On the same immutable trial-start temperature/water profile as the hydraulic modifier, the source-bound classifier identifies the legacy deep-frost/available-air branch. The normal branch delegates to admitted B6. The low-air branch evaluates the guarded B7 bracketed geometry, using actual node positions/distances and the prescribed sensible thermal surface temperature. Uniform or unbracketed front geometry is unavailable. The original decrement-before-test index policy is retained; last-node correction and a new fully frozen front interpretation remain separate.

In the low-air branch a drain level above the frozen bottom has all its nodal rates zeroed. Remaining nodal rates retain their original signed values, following the corrected ordinary source; they are not transferred from qbot or progressively rescaled across retries. If the remaining level sum is below1e-6cm/day and the frost bottom is below the deepest physical drain, qbot is zero; otherwise its separate owner remains unchanged. Level and aggregate reports derive from the final nodal rates. The solver source/sink provider and existing mass ledger use these same nodal rates exactly once.

The pure kernels are compared with actual corrected B1 FrozenCond/FrozenBounds at O0/O2. Forty-eight geometry cases retain bitwise top/bottom/index identity, and 108 signed normal/low-air cases cover partial/all/no level cutoff, equal front/drain depth, tied deepest depths and cancelling signed levels. Final nodal and bottom rates agree bit for bit and reports agree with final node sums. Invalid uniform/epsilon front and nonnegative physical drain depths reject before nodal proposals are changed.

The actual runtime fixture uses the nonuniform grid from the historical FSI stub with a narrowly owned corrected distance vector: [.25,.5,.75,1,.5]cm. The shared historical stub has inconsistent all-one distances and correctly fails the new front-geometry check. Changing only typed parameters is correctly rejected by the serialized context's exact static-grid guard. The runner therefore generates a private static-grid copy with only the distance definition replaced; the shared fixture remains untouched for incumbent preservation. This is a test geometry repair, not a production grid or solver change.

The initial consistent-grid trajectory trial closed hard mass but failed the retained head horizon bound:1.106030e-5cm against1e-6cm, while temperature1.988516e-5C passed1e-4C. The original localhead1e-6cm budget was not a cumulative guarantee. Qualification now tests tighter local head control and solver convergence; horizon limits and hard mass1e-12cm remain unchanged. Negative results and recovery are recorded in `integration/audits/PPA_WU05B8_STATUS.json`.

The temporal full/half norm compares head/temperature and additionally rejects disagreement in the normal/low-air branch, blocked drain-level mask or blocked-bottom decision. Derived geometry/flux scratch is recomputed for each full, half, retry and fresh worker. No new committed physical state or restart payload is introduced.

Excluded: active drainage-response generation, SWDIVD=1 redistribution, root/salt/macropore/snow composition, joint frost_bottom, groundwater-owned bottom, new last-node/fully frozen front physics, ice inventory and latent heat. This unit does not establish full legacy/global equivalence or complete aggregate frost migration.

Preregistration: `integration/audits/PPA_WU05B8_PREREGISTRATION.json`. Run `bash tests/frost/run_ppa_wu05b8_low_air_source.sh` and `bash tests/frost/run_ppa_wu05b8_low_air_runtime.sh`.
