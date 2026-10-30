# DATAQUAL15 low-demand microscopic root closure

Scientific source: `ad51bc80f1dd5c873cb52f3c98a34f2ded19c7a0`, based on `e51922789168ac4e271fabb6d538890bad677186`. Experimental; no canonical or full scientific-equivalence claim.

## Actual cause and repair

The unchanged original Hupsel execution stopped inside day1058, at1058.12–1058.16. An exact-checkpoint phase replay reproduces its37 attempts/32 solver rejections/2 temporal rejections and isolates `MICRO_DW_NO_CONVERGENCE` before Black, oxygen, salinity, Richards and heat for the failing retries. Rutter preparation is valid. Potential transpiration0.002183516521454538 cm/day is far above the source NIHIL threshold; all14 rooted-node densities are positive.

The independent microscopic soil/root flux certificate fails by1.019%. A representative diagnostic has root uptake0.002210540956295047 versus reconstructed soil supply0.002188018246055136 cm/day. Only node14 supplies water: its radial coefficient is407.685, and its inner pressure update is9.31e-6 cm. The unchanged original Newton head tolerance is1e-5 cm. The pressure-only stop therefore underresolves a small positive nodal flux, even though the unchanged absolute leaf residual1e-4 cm/day passes. Reducing Richards dt cannot repair that same-base process solve.

The existing final certificate runs first without modification. Only if it fails does a second evaluation refine the SAME root pressure, requiring both the original Newton head criterion and the already mandatory1% independent soil/root certificate. Both final leaf and flux checks still apply. The pre-cap certificate, demand-cap ordering, strict demand bound, published nodal vector, mass ledger, all parameter values and all solver tolerances remain unchanged. No persistent state, disk layout, process owner or numerical warm-start field was added. Already-certified cases keep their incumbent execution path.

## Executed qualification

- Actual original day1058→1096:38 complete days,9,812 accepted substeps, return0 in O0 and O2. Native time19.1537s O0 /12.1622s O2.
- All seven streams are byte-identical O0/O2: water/chemical budget, crop, germination, final state, endpoint, physical restart and joint checkpoint.
- Maximum water residual2.41265e-14 cm; reactive chemical residual3.42573e-14 mg/cm2; observed heat residual6.49703e-13 J/cm2.
- Actual O2 fresh-process split1058→1077→1096 matches uninterrupted execution: final joint checkpoint, state, endpoint and physical restart bytes, plus all19 resumed budget rows.
- Existing standalone microscopic owner and corrected literal B1.11 source oracle pass O0/O2 identity. All source-oracle outputs remain byte-identical to the preceding qualified microscopic oracle, including stress partition, saved zero-demand factor and invalid-optimum controls.
- The seven existing Black/bootstrap/common-forcing/Rutter/microscopic/root-hydrology native contracts were re-executed after rebuilding both changed production modules at this exact source. Every O0/O2 output remains byte-identical to its preceding cf2bd2f result. Original test drivers and their original fsi04/real-HeadCalc context are unchanged.

Every one of the235 inherited Hupsel provider source hashes was independently checked against the base Git commit in O0 and O2. Only the microscopic root owner differs at ad51bc8; it was compiled with gfortran13.3, bounds/runtime checks, backtrace and invalid/zero/overflow traps. Inherited object hashes, compiler/link/native commands, source postimage, original input files, causal diagnostic sources/results and binary endpoints are recorded. Executable hashes are archived separately to keep this evidence compact.

The incoming day1058 checkpoint is used literally, without rebinding. This qualifies the repaired continuation and exact restart; the parent campaign owns the fresh day1→1096 execution, full donor comparison and canonical merge. It is not counted as an independent original project or complete scientific equivalence.
