# F-SI04 - HeadCalc main workspace replay

## Status

`QUALIFIED_SOURCE_BOUND_MAIN_WORKSPACE_REPLAY_ONLY`

F-SI04 proves that the main B1.10 HeadCalc Newton, Jacobian, residual, tridiagonal-solve and hydraulic scratch can be redirected to the F-SI-owned `reference_richards_workspace_t` without changing the focused reference result or solver route. It deliberately does not yet switch the production route.

## Exact source basis

- F-SI03 qualified head: `c14ad3e032dd0285825051d8cf0e7d11ade01cd6`
- canonical B1.10 HeadCalc blob: `225b9f2cc1ecff01414b5691799103b92bc068c5`
- F-CI18 closeout: `7f906fcc53a4133b0e410eac7cf79fbb4eb672ab`
- qualified production-source head: `da5026d8b87ad2f3c7912360891839a120ecccb6`
- F-KT head observed at closeout: `0ed2c7204cedc249ae07ef5f1deec98adf32f49d`
- F-KT/F-SI boundary remains blob `ee1a153c30bbae9416ce08414e8b56049d3d14db`

The canonical `headcalc.f90` is byte-identical to F-SI03. F-SI04 uses a fail-closed generator to materialize a temporary workspace-backed candidate from that exact blob. This prevents an unqualified handwritten postimage from becoming a new source of truth.

## Scratch ownership proved on the generated source-bound path

The generated candidate redirects:

- `dFdhL`, `dFdhM`, `dFdhU` to the workspace Jacobian bands;
- `F` to workspace residual storage;
- `difh` to workspace Newton increment storage;
- `sink` and `source` to workspace source/sink storage;
- `hold` to workspace old-head scratch;
- `qv` and `hgrad` to workspace flux/gradient scratch;
- `flnonconv1`, `flnonconv2`, `flunsatok` to workspace convergence flags;
- `ctx%headcalc%dkdh` to workspace conductivity derivative storage.

The internal `vector_F` receives the same head-gradient storage by host association on the generated path. Residual expressions themselves are not rewritten.

## Executable qualification

Workflow run `34122972659`, job `101745034729`, tested head `0cfbefc271447b4b53eeee50c1dfbb2acaf020df` passed with GNU Fortran 13.3.0.

The gate compiles and executes both the exact original HeadCalc and the generated workspace-backed HeadCalc at O0 and O2. It compares their output byte-for-byte. The generated workspace is poisoned with NaNs before use. The focused A/B/A replay verifies repeated-call identity, solver-route identity and no contamination from prior workspace contents.

The fixture exercises the real HeadCalc source on a deliberately short matrix-flow, explicit-conductivity, free-drainage route. The unrounded focused equation residual is checked directly and remains zero within machine precision. This is useful mass-conservation evidence for the exercised HeadCalc equation, but it is not a full SWAP water-balance qualification.

F-SI03 adapter tests are rerun at O0/O2. F-SI02 workspace tests are rerun at O0/O2 with 1, 2, 4 and 8 OpenMP workers.

## Explicit holds

F-SI04 does not yet qualify full reference-solver reentrancy. The real production path still has broader legacy global state and the legacy `SAVE` compatibility worker. Parallel real-HeadCalc calls therefore remain unqualified.

The rare `alternative_solver` banded fallback still owns local `a`, `a1`, `b` and `indx` scratch. That path is deliberately left visible for F-SI05 rather than being silently included in the main-workspace claim.

Macropores, implicit-K, minimum-timestep behavior, non-free-drainage lower boundaries and explicit top-boundary provider extraction remain outside this slice.

## Legacy compiler warnings

The source-bound compile also makes several pre-existing warnings visible:

1. conservative compiler warnings for `i-1` references inside loops guarded by `if (i > 1)`;
2. `sum1` may be used uninitialized;
3. the `dkmean` function result may be uninitialized for values outside its implemented `swkmean` cases.

The warnings occur in the legacy source independently of the workspace transformation. F-SI04 does not change them because doing so would mix structural isolation with numerical/source-policy changes. The latter two deserve a separate source/numerical audit before broader solver-route qualification.

## Production change control

No existing production source was modified in F-SI04. In particular, `headcalc.f90`, `soilwater.f90`, worker context, transaction source, F-SI02 solver contract/workspace and the F-SI03 adapter remain unchanged. Production routing has not been switched.

## Next

F-SI05 should turn this qualified generated transformation into a committed workspace-aware HeadCalc production seam while retaining explicit legacy compatibility. In the same logical ownership slice, the rare banded fallback scratch can move to worker-owned storage and receive a dedicated fallback replay test. Formula and numerical-policy changes remain out of scope.
