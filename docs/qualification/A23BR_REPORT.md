# A23BR - Explicit timestep ownership

## Status

`PASS_TIMESTEP_OWNERSHIP_SPLIT / LEGACY_GLOBAL_DT_BACKEND_PROJECTION_REMAINS / PHYSICAL_BACKEND_SERIAL_ONLY`

A23BR removes the next two active timestep-control singletons from the B1.6 execution path and makes the lifetime of `dt` explicit.

## Changes

- `variables%fldtmin` removed from the transformed 63-file B1.6 source tree.
- `variables%fldtreduce` removed from the transformed 63-file B1.6 source tree.
- `fldtmin` semantics moved to `worker%control%at_min_dt`.
- `fldtreduce` semantics reduced to local `repeat_current_step` in the SWAP retry loop.
- `column%numerical%dt` remains the persistent per-column numerical continuation state.
- The Hupsel component seeds `at_min_dt` from restored column `dt` and configured `dtmin` before each trial.
- Attempt reset clears retry request/iteration control but preserves the derived minimum-step flag.

## Dynamic contamination test

Before interleaved physical advances the test deliberately poisons:

- legacy global `variables%dt` with unrelated positive/negative values;
- `worker%control%last_numbit`;
- `worker%control%request_dt_reduction`;
- `worker%control%at_min_dt`.

The component then restores the logical-column state and re-seeds timestep control. Both logical columns reproduce their independent serial reference state and diagnostics exactly. The gate prints `A23BR_TIMESTEP_OWNERSHIP_POISON PASS`.

## Physical B1.6 qualification

O0 and O2 physical logs are byte-identical, SHA-256:

`ad65f238e796ea51598bf22da2e93de3d299fadf0bfbd92a14a8bce2f7c6b5a0`

The complete 1032-byte B1.6 continuation endpoint remains:

`4b77a52ca7c48a59a057dec036f596a8da4ebc9ede9296f7d3b36dcff528bfb9`

Accepted storage is `77.011710672204643 cm`. The accepted two-half mass residual is `-1.7872350177583485e-7 cm`, inside the fixed B1.6 `1e-6 cm` criterion.

Direct solver cost is unchanged:

- 162 / 81 HeadCalc calls, total reference / accepted route;
- 956 / 478 Newton iterations;
- 956 / 478 Jacobian builds;
- 956 / 478 linear solves;
- 1350 / 675 backtracking attempts;
- 20 / 10 internal retries;
- 0 alternative solver calls.

The committed next-step value after the accepted two-half route is:

`dt = 6.2205964537924707e-3 d`

## Worker isolation

Eight worker contexts execute 1000 independent mutation/control cycles each: 8000 checks, 0 failures. O0/O2 log SHA-256:

`c949922ffc3898981a1be2a5cb1085953c16bb357300ad79ee71494130ecec9d`

The worker numerical-control object occupies 12 bytes with GNU Fortran 14.2: one 4-byte integer and two 4-byte logicals. Only `at_min_dt` is new in A23BR. HeadCalc scratch remains 3292 bytes per 34-node worker.

## Generic transaction regression

O0/O2 generic transaction log remains identical with SHA-256:

`8364385f32219a588fa7b04d776f07732cb13de9f08e4eb6e95a1a0a5abf9548`

## Source audit

Across all 63 transformed source files, active-code occurrences are:

- `fldtmin`: 0
- `fldtreduce`: 0
- legacy `numbit`: 0
- legacy `fldecdt`: 0

`dt` intentionally remains in the legacy backend: 531 active references in 21 files. This is the remaining projection boundary, not a claim that B1.6 is already fully free of singleton numerical state.

## Jacobian identity

The complete `jacobian_F()` block is byte-identical between A23BQ and A23BR:

`ed7a8643d59350f4db5315cd27750d7a6df2b790a35eb91ed4549fbadacbeda8`

No Jacobian formula changed.

## Postimage hashes

- `headcalc.f90`: `458c53339f6815cf420e7745e9d3dd61fede136250bc6af1a20cad3bb6c0dfc8`
- `timecontrol.f90`: `bb73e8e6784615a26c1a928218b1e3500d4724c262d76d8b18064fd0bfc2d0fa`
- `swap.f90`: `2319c46db5fb875c2f4c9e93dc798ce300d0c3ee33cbdbd9b7159a2f78af26d8`
- `surfacewater.f90`: `6b770314aa5577ef9b7853ca76b66208a5960ea39605daec01cda994d1bafe27`
- `variables.f90`: `44ee8f4255a0327c0e24f8fce27e1d72575cc980b74f7d16e5fa3a6afbdbb2f8`
- `initialize.f90`: `7adfc66a7f18cffc38ac279e28f09e0af30247cf6a013a020595d81b8b54713b`

Parent B1.6 source manifest remains `aad530d2b683aa25ed8d5ec87656fb3790b8d8f8faf6bff4b03d40a4c60136a0`.

## Remaining boundary

The B1.6 physical/process backend is still serialized and still exposes global `dt`, calendar/progression state and many process globals. A23BR does not change selective step doubling. It also does not claim that the Hupsel integer-day VQ adapter is the final generic-time production interface.
