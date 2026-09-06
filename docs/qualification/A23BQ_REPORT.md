# A23BQ - Worker-owned Richards/retry numerical control

## Status

`PASS_WORKER_OWNED_RICHARDS_RETRY_CONTROL / PHYSICAL_BACKEND_SERIAL_ONLY`

A23BQ advances the A23BP worker-scratch cut by removing two active singleton numerical controls from the B1.6 physical execution route: `variables%numbit` and `variables%fldecdt`.

## What changed

The worker execution context now contains `last_numbit` and `request_dt_reduction`. HeadCalc writes these values directly. TimeControl reads them directly. SWAP, MOD_drain and SurfaceWater use the same worker request flag rather than the old global `fldecdt`.

After the dynamic path had been qualified, the obsolete `numbit` and `fldecdt` declarations and initialization writes were removed from the transformed `variables.f90` and `initialize.f90`. A source audit over all 63 transformed Fortran files finds zero active-code occurrences of either legacy singleton name.

The added raw worker control payload is 8 bytes. Existing A23BP active-sized solver scratch remains 3292 bytes per 34-node Hupsel worker.

## Physical qualification

O0 and O2 both reproduce the exact B1.6 endpoint:

`4b77a52ca7c48a59a057dec036f596a8da4ebc9ede9296f7d3b36dcff528bfb9`

The O0/O2 physical gate logs are byte-identical (SHA-256 `6afd017134929ca85f6edd74a6c5bd12e487e6d31962c8b5189878fa8595a1bb`). Accepted storage remains `77.011710672204643 cm`; the two-half mass residual is `-1.7872350177583485e-7 cm`, within the fixed B1.6 `1e-6 cm` mass gate.

Direct solver cost is unchanged from A23BP: 162/81 HeadCalc calls, 956/478 Newton/Jacobian/linear solves, 1350/675 backtracking attempts, and 20/10 internal retries for total reference work / accepted route.

The generic transaction regression remains O0/O2-identical with SHA-256 `8364385f32219a588fa7b04d776f07732cb13de9f08e4eb6e95a1a0a5abf9548`.

## Worker isolation

Eight independent worker contexts pass 1000 mutation/control cycles each: 8000 checks, 0 failures. The O0/O2 isolation log is identical with SHA-256 `69a31bb5f6838a5c395029326a33edba08ce6bc3c5f4fb66eea3ad7d1cf5a175`.

The test explicitly resets, sets and verifies `last_numbit` and `request_dt_reduction` independently per worker in addition to the A23BP HeadCalc scratch poisoning.

## Source postimages

From exact B1.6 parent manifest `aad530d2b683aa25ed8d5ec87656fb3790b8d8f8faf6bff4b03d40a4c60136a0`:

- `headcalc.f90`: `c30c9c6ecfe5825f1edda59809bccfb8d03727173a0b8010e984a206c44e7ee0`
- `soilwater.f90`: `3af37d6f0bdc3d18e911936f8b41746b5cf6a3cc660ec65bdc2ac7ac17f7f6a6`
- `timecontrol.f90`: `8a3bbc213064a8047fdf81ddcf017219ffb7a232c55448521d4c48dc82b9b406`
- `swap.f90`: `42715264483af74abd155ea56ea705d1e331b2e94b735c12df041caa97732e2c`
- `surfacewater.f90`: `0cc9990687aeefbf220a543daeda280e3236b608038f81990b38059fbf8e31b9`
- `MOD_drainage.f90`: `997743f14c2c4f6045c8b04d45141bd7489acfb5df46cf0a544cc4d6ee482db6`
- `variables.f90`: `94d4194b40be1c94e5a7b97ebeed49eace5b4ea02c9b1fbe8b5bb2781d8635b8`
- `initialize.f90`: `1858aca2b18236f5099b44d764831afcad474762a08b0bad18579bb5e254f5bc`

The complete `jacobian_F()` block is byte-identical to A23BP (`9ba4ada31fe629a006d47f30d77b8c6f8a200b232a91483b31735a6b53fb38cb`).

## Invariant assessment

- 3/4: numerical execution control stays separate from physical column continuation state.
- 5: improved; retry/iteration control now follows worker ownership together with HeadCalc scratch.
- 6/16: worker contexts remain active-sized and pass independent parallel isolation tests.
- 7/8: transaction checkpoint/retry/commit behavior unchanged.
- 9: no new day/calendar assumption is introduced by the control contract; the Hupsel VQ adapter itself still uses integer-day intervals.
- 13: hard physical mass gate unchanged and PASS.
- 23: numerical ownership changed; numerical policy and physics did not.
- 24/26: retry request and direct solver-cost diagnostics are explicit worker/runtime information.
- 30: exact parent identity, deterministic transformer, postimage hashes and O0/O2 gates retained.

## Remaining boundary

The physical backend remains serialized. In particular `dt`, `fldtmin`, `fldtreduce`, time/progression variables, process globals and many physical module states are still singleton-owned. SurfaceWater receives the new worker retry signal but its extended-drainage path is not dynamically qualified by Hupsel (`SWDRA=1`). Selective step doubling is unchanged.
