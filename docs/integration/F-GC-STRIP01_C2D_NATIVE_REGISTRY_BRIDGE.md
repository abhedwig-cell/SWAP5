# C2D native registry bridge probe

**State:** `NATIVE_FGC49D_REGISTRY_ZERO_CONTROL_PUBLISHED`; dynamic Dummy-SWAP through the native registry remains unimplemented.
**Local source commit:** `7b40be4f5e63197f9a97638381ffaa79df3585f2`
**C2D baseline:** `ac87e2484b1ecc54c8eac9072cd6f9248fbeb5e9`

## Executed control

The existing 50-participant C2A fixture (`tests/fgc/strip01/research_context_c2a.f90`) was rebuilt from the current branch source with `tools/build_f_gc_strip01_research_context.py --profile C1`, then run twice in fresh processes against MODFLOW6 6.8.0. It uses the native F-GC49D C API, native Fortran participant registry/application context, native F-GC34 package publisher and the 50-cell MODFLOW strip. The trial has zero top flux, matched -1 m heads and one 0.001-day window.

Both processes reported `FIRST_WINDOW_PUBLISHED` and their result JSON was byte-identical. All 50 heads and interface residuals remained exactly -1 m and 0 m/s, respectively. Each of the 50 real-SWAP registry participants advanced one committed revision and one interface-ledger count. Complete-domain residual was zero. The compact run record, full source manifest and SHA-256 identities are in `integration/f-gc/strip01/results/c2d-local/native_registry_zero_control.json` and its linked artifacts.

This is a real-SWAP native-registry zero-control. It confirms a one-window hydrostatic publication through the current native topology and does not exercise a Dummy-SWAP participant or the C2D dynamic response.

## Why the dynamic dummy cannot be inserted through the current registry

`src/runtime/mod_fmr_groundwater_participant_registry.f90` stores `fmr_groundwater_swap_participant_t` and `fmr_serialized_reference_backend_t` as concrete types. The participant's trial path calls `backend%run_trial`, and its accepted publication calls `backend%commit_trial_candidate`. The latter owns committed-state revision and candidate publication. There is no backend/participant factory or response-provider seam through which the C2D analytic storage law can enter while retaining the actual F-GC49D registry.

The existing C2D strip calls the F-GC49C Python service with an analytic transactional DummyRuntime, followed by the native F-GC34 publisher and MODFLOW6. Replacing only its Python object with `FmrGroundwaterApplicationRuntime` would call the real registry's Richards trial and transaction; overriding its returned q alone would decouple the published physical SWAP state from its flux and invalidate the dummy storage ledger.

## Bounded result and next design decision

The evidence now establishes both (a) complete dynamic Dummy-SWAP response through the F-GC49C service/MODFLOW route and (b) the one-window 50-participant F-GC49D real-SWAP hydrostatic control. C2B separately documents the dynamic real-SWAP failure. It still does not provide an apples-to-apples dynamic C2D dummy response through the same native participant registry.

Closing that specific gap requires an explicit test-only backend/participant contract accepted by the F-GC49D context, including candidate storage, origin/revision identity, rejection rollback, publication and ledger ownership. The safe next step is to preregister and review that seam as an additive research capability with unchanged default real-SWAP behavior. Do not fabricate a native dummy result by changing q after a Richards trial, and do not modify production tolerances, transaction policy, or canonical storage/drain ownership.
