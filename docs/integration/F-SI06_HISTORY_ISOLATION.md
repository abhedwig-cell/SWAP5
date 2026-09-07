# F-SI06 HeadCalc history isolation

## Status

`QUALIFIED_HISTORY_ISOLATION_PARALLEL_BINDING_BLOCKED`

F-SI06 removes hidden persistent ownership from HeadCalc and makes cross-call history explicit without changing Richards physics, numerical policy, transaction semantics or generic time semantics.

The qualification is deliberately narrower than full solver reentrancy. The common reference workspace and history carriers are isolated, but the current legacy reference adapter still translates request and candidate state through mutable legacy module globals. Real concurrent HeadCalc execution is therefore not admitted by F-SI06.

## Exact basis

- F-SI05 qualified head: `0227ae94edc3364b013f831f1efa6aaccac29b11`
- F-SI06 production materialization: `8decd3520b34f1f53e1c8001ca33dde9150f5e09`
- corrected legacy oracle: B1.10
- F-CI18 canonical closeout: `7f906fcc53a4133b0e410eac7cf79fbb4eb672ab`
- qualified production-source head: `da5026d8b87ad2f3c7912360891839a120ecccb6`

Materialized production blobs:

- `src/legacy/b1_10_port/headcalc.f90`: `38de52dd9f13b70a61f418c29a5c2e4bc9a449a9`
- `src/legacy/b1_10_port/soilwater.f90`: `aa072804768b7a982b275d3a7d6988bfed6b9faa`
- `src/adapter/mod_reference_richards_legacy_binding.f90`: `f60f7ef2d60ccb8cc78e80d56ef88a739e50ab2e`

No F-KT transaction source, shared worker type, common solver contract or reference workspace layout was changed.

## Ownership result

### Worker/job execution state

Newton, Jacobian, linear-solve and other attempt-local solver data remain worker or active-job owned. F-SI06 does not add persistent solver scratch to logical column state.

### `flwarn` and `iwarn`

These fields only control legacy warning/reporting history and do not determine the physical solution. On the common reference path HeadCalc receives a call-local explicit history carrier. Standalone legacy compatibility retains explicit persistent reporting history in `MOD_SoilWater`.

### `nstep`

`nstep` is not solver scratch. On the macropore path it participates in the accepted-step evolution of `IDecMpRat`, so it can affect later physical/numerical process behavior.

The common reference adapter still rejects `swmacro != 0`, therefore F-SI06 does not materialize `nstep` into a new committed state type. F-KT06 independently defines the matching lifecycle rule: physics-affecting optional continuation belongs in the existing opaque per-column transaction-state lifecycle and `nstep` must be adapter-specific transaction state before macropore admission. At the F-KT06 head observed during F-SI06 closeout, that F-KT06 contract was persisted but not yet qualification evidence.

## Source change

HeadCalc now accepts:

`headcalc(worker, fsi_workspace, history)`

All three arguments remain optional for source compatibility, but the common production adapter passes worker, workspace and a separate call-local history explicitly.

The hidden HeadCalc `SAVE` worker is gone. If HeadCalc is called directly without a worker or history, call-scoped local carriers are used instead of hidden persistent state.

`MOD_SoilWater` owns the legacy compatibility carriers explicitly:

- `legacy_headcalc_worker`
- `legacy_headcalc_history`

When an explicit legacy worker is supplied, `MOD_SoilWater` passes `worker%history`. This preserves the existing legacy execution model without making that path a MultiSWAP admission claim.

## Executable qualification

Workflow run `34127234890`, job `101758660973`, completed successfully with GNU Fortran 13.3.0.

The gate demonstrates:

1. exact F-SI05 versus F-SI06 focused output identity at O0 and O2;
2. normal tridiagonal and forced real band-fallback route identity;
3. serial A/B/A repeat and order independence on the focused admitted route;
4. explicit day-start history mutation reaches the supplied history carrier and does not mutate worker history;
5. an adapter testdouble that deliberately mutates the explicit history carrier cannot contaminate persistent `legacy_worker%history` across A/B/A calls;
6. the changed production `MOD_SoilWater` interface compiles at O0 and O2;
7. the common reference workspace remains isolated at 1, 2, 4 and 8 OpenMP workers at O0 and O2;
8. the focused unrounded equation residual remains identical and closes to machine precision;
9. the unchanged F-KT transaction/worker substrate regression remains green.

Pre-existing guarded-index and possible-uninitialized compiler warnings are retained as separate audit items and are not changed by this ownership slice.

## Parallel admission blocker

F-SI06 intentionally does not execute concurrent calls through the common real HeadCalc adapter as if they were safe. The adapter still writes each request into shared legacy module variables including `h`, `theta`, `hm1`, `thetm1`, `pond`, `gwl`, `pondm1`, `gwlm1`, `qtop`, `qbot`, `fldecdt` and `numbit`, then restores them after HeadCalc.

Separate worker/workspace/history instances cannot make that translation reentrant. Concurrent calls could interfere before restoration. The gate therefore records:

`F-SI06_REAL_PARALLEL_ADMISSION BLOCKED_SHARED_LEGACY_GLOBAL_TRANSLATION`

This is a fail-closed architecture result, not a failed history-isolation qualification.

## Invariant assessment

F-SI06 is consistent with invariants 1, 3, 4, 5, 6, 7, 8, 13, 14, 16, 20, 21, 22, 23, 24, 25, 26, 27 and 29 within its qualified scope.

In particular:

- scratch remains outside persistent column state;
- reporting history is separated from physics-affecting continuation;
- physics-affecting optional continuation is not hidden in reusable worker scratch;
- no transaction lifecycle is redefined by F-SI;
- no solver formula or external policy is changed;
- mass conservation remains a hard requirement;
- no full parallel or MultiSWAP admission is inferred from workspace-only concurrency tests.

## Holds

F-SI06 does not qualify:

- real HeadCalc 1/2/4/8 concurrent execution;
- macropore production execution;
- adapter-specific `nstep` transaction materialization;
- implicit-conductivity execution;
- minimum-timestep route;
- non-free-drainage bottom modes;
- full SWAP unrounded water-balance identity;
- an interface response tangent;
- production MultiSWAP.

## Next slice

F-SI07 should remove the common solver path's dependence on shared legacy request/candidate physical-state globals. The target is an explicit per-solve state/evaluation binding that keeps formulas and numerical policy unchanged and makes a deterministic real HeadCalc 1/2/4/8 reentrancy qualification technically meaningful.
