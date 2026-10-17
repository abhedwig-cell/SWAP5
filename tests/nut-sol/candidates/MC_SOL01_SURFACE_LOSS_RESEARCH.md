# MC-SOL01 surface-loss candidate: scientific and integration boundary

Status: **EXPERIMENTAL / NOT PRODUCTION / NOT ADMITTED**. Draft PR #1288.
Base canonical `e51efd1f14de328db22d2c32a6ca78bc228d01b0`.
Only `tests/nut-sol/candidates/` is changed; the accepted water and chemical owners remain untouched.

## Numerical assumption under test

The leaf evaluates a lumped, fully mixed event: initial pond mass plus gross rain/irrigation/dry deposition is immediately mixed in the initial pond water plus gross incoming water. Infiltration and runoff withdraw at that common concentration. Evaporation removes water without removing dissolved mass. This is an **explicit hypothesis**, NOT yet established as the historical SWAP 4.3.1 calculation. It does not provide runon, age, equilibrium solubility or crystallization physics, chemical reactions, or arbitrary switching of boundary regimes. It must not be wired into a production owner without a source comparison and accepted hydraulic receipts.

## Scientific counterexample: within-event ordering

For depth=1 cm, mass=2 mg/cm2, followed by 1 cm rain with concentration 3 mg/cm3 and 0.5 cm infiltration, the single mixed step exports 1.25 mg/cm2 and retains 3.75 mg/cm2 at 1.5 cm water depth.

Splitting the event into 0.25 cm infiltration **before the rainfall**, then 1 cm rain and another 0.25 cm infiltration, exports 0.5 + 0.6428571428571429 = 1.1428571428571428 mg/cm2, retaining 3.857142857142857 mg/cm2. Difference in retained mass is 0.1071428571428572 mg/cm2 despite equal cumulative forcing and final water depth. This reflects chronology and the instant-mixing assumption; it is not by itself a conservation failure. It demonstrates why net top flux and end-of-interval water depth cannot determine the solute transfer.

## Executed independent leaf checks

GNU Fortran 14.2.0, flags `-std=f2008 -Wall -Wextra -Werror -fcheck=all`; O0 and O2 compile and execute with:
- Original hand-computed wet, dry-retention, rewetting and overdraw driver: `SURFACE_LOSS_BUDGET=PASS` twice.
- Additional deterministic 40-case water/mass positivity/closure sweep and three invalid-input controls: `SURFACE_LOSS_SWEEP_PASS=40` at both O0 and O2.

These checks are leaf-level ONLY, and **do not** demonstrate actual SWAP5 production science, native restart, accepted-substep coupling or preservation of previous admissions.

## Integration gates before promotion

1. Compare against historical SWAP 4.3.1 equations, parameter semantics, pond mixing/salt crystallization and ordering, including low-depth dry residue.
2. Identify an already accepted hydraulic water owner emitting gross rain, irrigation, evaporation, infiltration, runoff and runon **separately per accepted substep**, plus start/end pond depth. Do not infer these from net `qtop`.
3. Reuse existing matrix companion `pond_mass`, the PR #1256 V2 restart codec and PR #1257/#1258 joint transaction. No second committed mass owner and no production restart format changes.
4. Prove water and total soil-plus-surface mass, external inputs/outputs, exact accepted trace contiguity, failed water trial, chemical rejection and smaller retry, and native fresh-process restart.
5. Preserve qualified incumbent PRs #1234/#1256/#1257/#1258 and separate TOP03 research PR #956. Aquifer remains excluded.
6. Select and execute real production O0/O2 physical drivers and owning source-bound guards before even proposing mastercoverage promotion or canonical merge.

Only after those gates may a production candidate be marked qualified. Draft PR #1288 must not be merged in its current state.
