# A23BP - Per-worker HeadCalc execution context

## Status

`PASS_WORKER_OWNED_HEADCALC_SCRATCH_AND_DIRECT_SOLVER_DIAGNOSTICS / PHYSICAL_BACKEND_SERIAL_ONLY`

A23BP is the first explicit worker-scratch extraction above the A23BO per-column state split. It keeps the qualified B1.6 Hupsel trajectory as the physical oracle and changes ownership and observability only.

## What moved

The principal HeadCalc/Newton/Jacobian workspace is now represented by `a23bp_worker_context_t`. Active-sized arrays include the three Jacobian diagonals, residual, Newton correction, source/sink vectors, `dkdh`, previous head, flux/gradient work arrays and convergence flags. Legacy HeadCalc `SAVE` variables `dkdh`, `flwarn`, `iwarn` and `NStep` are no longer SAVE-owned on the A23BP path.

Hupsel has 34 active nodes. Worker scratch payload is **3292 B**. Eight workers therefore carry 26,336 B; the same allocation incorrectly attached to 100,000 columns would be 329.2 MB.

## Direct cost diagnostics

The legacy `itnumb`-derived count used in A23BO was not a direct operation count. Direct instrumentation now observes for the always-sampled 4-5 January transaction:

- total HeadCalc calls: 162; accepted route: 81;
- total Newton iterations: 956; accepted route: 478;
- total Jacobian builds: 956; accepted route: 478;
- total linear solves: 956; accepted route: 478;
- total backtracking attempts: 1350; accepted route: 675;
- internal retries: 20 total; 10 accepted route;
- alternative solver calls: 0.

Thus A23BO's 356 weighted iteration statistic is retained only as legacy evidence; 956 is the direct operation count for this reference evaluation.

## Physical qualification

O0 and O2 gate logs are byte-identical (SHA-256 `b19b589cb807438e5e7954acdd51ca7fd05591d7968adc84cf20aab4ae2fa58b`). The final 1032-byte B1.6 continuation state is exactly `4b77a52ca7c48a59a057dec036f596a8da4ebc9ede9296f7d3b36dcff528bfb9` under both builds. Accepted storage remains 77.011710672204643 cm and the two-half mass residual remains -1.7872350177583485e-7 cm, inside the 1e-6 cm B1.6 gate.

The normalized Jacobian block is unchanged: original and worker-owned normalized SHA-256 are both `f522380f8340bb6915196259af191bebccd2d4feabbd7fa71a5a793e20af305e`.

## Worker isolation

Eight worker contexts were mutated in parallel for 1000 cycles each: 8000 checks, 0 failures. This qualifies worker-context ownership and reuse, not parallel execution of the still-global B1.6 physical backend.

## Postimage identities

The exact transformed B1.6 source postimages used by the A23BP physical gate are:

- `headcalc.f90`: `486291e9ea7f3d5809774cf828ca5a5d31ea3e307a909b0cd5979945013a05d6`
- `soilwater.f90`: `2d23eed04fd3baaed7cc36329d84dc46514ee1c98c72d724073c66f049f4d19e`
- `timecontrol.f90`: `92c3bc5634966313fb62f14318aa7376be98080628120195678e9b659141850a`
- `swap.f90`: `7d7b65ec751bd13ab26cd94bd0b9d7bb80bd15ccd3a8a1d2ae67ab9da8133fd8`

These are derived from the exact B1.6 parent manifest `aad530d2b683aa25ed8d5ec87656fb3790b8d8f8faf6bff4b03d40a4c60136a0` by the retained A23BP preparation tool.

## Invariants

- 3/4: column state remains separate from worker numerics.
- 5: materially improved; principal HeadCalc/Newton/Jacobian scratch is worker-owned.
- 6/16: active-sized worker payload and parallel context isolation qualified; physical backend remains serial.
- 7/8: A23BL checkpoint/retry semantics unchanged.
- 13: physical mass gate unchanged and PASS.
- 23: no solver policy or physics change.
- 26: direct solver operation diagnostics are first-class results.
- 30: exact B1.6 parent, transformed postimage hashes, tests and contracts retained.

## Remaining boundary

The B1.6 physical/process modules are still singleton-global. Alternative-solver local arrays and other process-specific solver scratch remain for later extraction. No claim of full thread-safe MultiSWAP physics is made. Selective step doubling is unchanged.
