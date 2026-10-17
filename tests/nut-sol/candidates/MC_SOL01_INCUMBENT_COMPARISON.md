# MC-SOL01: source comparison, October 17 2026

This supplement is tied to draft PR #1288 head `1715e9379a936bfe83361a8c6aa2c4a55a916406` and canonical `e51efd1f14de328db22d2c32a6ca78bc228d01b0`.

## Existing accepted production equation

The current canonical `src/process/mod_b111_pond_solute_exchange.f90` computes, when `qtop < -1e-6`, `denom = pond_end - qtop * dt`, `pond_concentration = available / denom`, and `soil_transfer = -qtop * (1-macropore_area) * pond_concentration * dt`. The new candidate uses `available / (depth_start + (rain+irrigation)*dt)` for runoff and infiltration. These are identical for the zero-evaporation/zero-runoff surface water budget and `qtop = -infiltration`. They differ if evaporation has depleted surface water during the substep. For depth 1 cm, surface solute 2 mg/cm2, evaporation 0.5 cm and infiltration 0.25 cm, ending depth 0.25 cm: the literal incumbent concentration rule gives 1 mg/cm2 of soil transfer, the proposed pre-loss mixing rule gives 0.5 mg/cm2. This discrepancy is demonstrated by the O0/O2 local `test_surface_loss_incumbent.f90` **literal oracle**; it does **not** compile the incumbent production module.

Separate `test_surface_loss_order.f90` verifies the temporal ordering example: 3.75 mg/cm2 remains for the one-shot mixed step, while 3.857142857142857 mg/cm2 remains if 0.25 cm of infiltration occurs before rain and another 0.25 cm after; final water depths match. Thus an end-state flux reconstruction cannot infer chemical mixing chronology.

## Historical constraint

The existing `integration/audits/SWAP431_RUNON_REPAIR_STATUS.json` traces SWAP 4.3.1 B1.11 runon into the canonical hydraulic dynamic-top donor and identifies the archive `integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64`. This is evidence of **runon water input ownership**, not proof that chemical runon mass or its concentration is accepted. The original donor source has not yet been inspected here to determine the source-exact solute loss ordering. Do not call the current candidate historically qualified.

## Engineering decision

Do NOT connect draft module to the accepted pond solute owner. First obtain actual accepted gross evaporation/runoff/runon hydraulic receipts with interval chronology; preserve zero-loss incumbent numerics and chemical restart. Select physical production O0/O2, exact previous surface endpoints, water/chemical rejection/retry, source comparison and native fresh-process restart. No canonical merge, new source owner or mastercoverage promotion is authorized by these standalone tests.
