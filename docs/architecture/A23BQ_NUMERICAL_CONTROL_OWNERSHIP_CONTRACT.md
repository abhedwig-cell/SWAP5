# A23BQ numerical-control ownership contract

## Scope

A23BQ removes the next active singleton numerical controls from the B1.6 Richards/retry route. The legacy module variables `numbit` and `fldecdt` are replaced by worker-owned execution control and are removed entirely from the transformed `variables.f90` / `initialize.f90` postimage.

No physical equation, Jacobian formula, timestep policy threshold, retry reduction factor, mass-balance rule or selective-step-doubling policy is changed.

## Worker-owned execution control

`a23bq_worker_context_t` owns an 8-byte raw numerical-control payload:

- `last_numbit`: iteration count from the current/last Richards solve, used by TimeControl for timestep growth or reduction;
- `request_dt_reduction`: an attempt-local request raised by HeadCalc or, for extended drainage configurations, SurfaceWater.

These values are execution state, not committed physical column state. They are reset/reused with the worker context and are not checkpointed as water state.

## Control flow

On the A23BQ route:

1. HeadCalc iterates with a local loop counter and copies the current iteration number to `worker%control%last_numbit`.
2. Failed HeadCalc convergence raises `worker%control%request_dt_reduction`.
3. SurfaceWater is wired to the same request flag for extended-drainage configurations.
4. SWAP and MOD_drain no longer branch on global `fldecdt`.
5. TimeControl reads `worker%control%last_numbit` for the existing timestep policy and consumes/resets `worker%control%request_dt_reduction` for the existing retry policy.
6. The old `variables%numbit` and `variables%fldecdt` declarations and initialization writes are absent from the transformed backend.

## Physical/reference qualification

For the B1.6 Hupsel 4-5 January always-sampled transaction, A23BQ preserves exactly:

- endpoint SHA-256 `4b77a52ca7c48a59a057dec036f596a8da4ebc9ede9296f7d3b36dcff528bfb9`;
- accepted storage `77.011710672204643 cm`;
- two-half mass residual `-1.7872350177583485e-7 cm`;
- 20 total / 10 accepted-route internal retries;
- 162 / 81 HeadCalc calls;
- 956 / 478 Newton iterations, Jacobian builds and linear solves;
- 1350 / 675 backtracking attempts;
- zero alternative-solver calls.

O0 and O2 physical gate logs are byte-identical.

## Jacobian preservation

The complete `jacobian_F()` block in A23BQ is byte-identical to A23BP. Both have SHA-256 `9ba4ada31fe629a006d47f30d77b8c6f8a200b232a91483b31735a6b53fb38cb`. The previously qualified normalized B1.6/A23BP Jacobian identity therefore remains unchanged.

## MultiSWAP meaning

This cut removes two active global numerical-control dependencies and makes the solver/retry decision chain worker-addressable. It does not yet make the full B1.6 backend parallel: `dt`, `fldtmin`, `fldtreduce`, physical/process module state and several caches remain global. The Hupsel physical gate remains serialized.

Extended SurfaceWater control wiring is compile-qualified but not dynamically exercised by Hupsel because the Hupsel fixture uses `SWDRA=1`.
