# F-VQ11 — downstream source-bound admission for F-KT04 and F-SI04

F-VQ11 is qualification-only. It starts from exact qualified F-VQ10 final head `82e9ec4ec4a3489dec771b8f53caf2c14a5eef20` and changes no production source, physics, numerical policy, solver tolerance, mass policy or production routing.

## Goal

Admit only the downstream contracts that already have exact source-bound qualification evidence after the F-CI18 canonical exit:

- F-KT04 committed temporal provenance and contiguous continuation;
- F-SI04 focused real HeadCalc main-workspace replay on the generated source-bound workspace path.

The two work units remain independently qualified. F-VQ11 does not infer that their combined runtime composition has been executed or qualified.

## F-KT04 boundary

F-KT04 qualified tested postimage `dfe9ac831428a65703e63e9f66673c6288ecc6fc` under workflow `34121637946`. Its qualification sequence is explicit:

1. tested postimage `dfe9ac831428a65703e63e9f66673c6288ecc6fc`;
2. evidence-only commit `acd55ecee8802a0a9fb5d854380622f2d20a7503`;
3. status-only promotion commit `65cfa7c855499cf2dba8ecb8ef4ab17548cc5a1c`, which records F-KT04 as `QUALIFIED`.

The admitted scope is committed temporal provenance, contiguous continuation, revision/time advancement on commit and fail-closed rejection of overlap, gap, backward or non-finite time.

F-VQ11 does not consume F-KT05. The observed F-KT05 postimage `ed0764126a9febdd8a14ff3f32fdba68e9be9e81` remains a negative admission fixture: its focused gate fails under `-Werror=compare-reals`. F-VQ11 confirms that failure is still reproduced and refuses to promote F-KT05.

## F-SI04 boundary

F-SI04 qualified tested postimage `0cfbefc271447b4b53eeee50c1dfbb2acaf020df` under workflow `34122972659`, job `101745034729`. Final qualification record head `c76f794b93522bea3a80a6880bc95ef5671cb914` adds only qualification documentation/evidence after that tested source postimage.

The admitted claim is narrow: exact canonical B1.10 HeadCalc is transformed deterministically into a generated candidate in which the main Newton/Jacobian/residual/tridiagonal/hydraulic scratch is redirected to F-SI-owned workspace on a focused matrix-flow/free-drainage route. Original and workspace paths are byte-identical in output for O0 and O2 on the admitted fixture, with workspace poison reset and ABA/repeat checks.

This is not a committed production workspace-aware HeadCalc seam. It does not qualify full real solver reentrancy, parallel real HeadCalc workers, alternative solver scratch, macropores, implicit conductivity, minimum-timestep behavior, other bottom modes or the full SWAP accounting chain.

## Ownership

The contracts remain non-overlapping in authority:

- F-KT owns committed state carrier semantics, revision, temporal provenance and commit/rollback authority.
- F-SI owns solver interface/workspace/scratch isolation and may return solver results or retry advice within its admitted scope, but does not gain commit or rollback authority.

F-VQ11 checks this boundary rather than composing the two implementations into a new runtime claim.

## Mass conservation

Mass conservation remains an absolute requirement. F-SI04 has a qualified focused unrounded equation-residual identity, but explicitly does not execute the complete SWAP water-accounting chain. F-VQ11 does not promote that focused residual into full SWAP mass-balance qualification.

## Qualification result

F-VQ11 is qualified as `QUALIFIED_FKT04_FSI04_SOURCE_BOUND_ADMISSION_ONLY` on tested postimage `98c9ede6e993c08a364a2148ed0aa6ff428f6d98`.

The qualifying runs are:

- dedicated F-VQ11 workflow `34125646655`, job `101753579651`: success;
- immutable VQ reference replay `34125646535`: success;
- documentation `34125646611`: success;
- compiler identity: GNU Fortran 13.3.0.

The dedicated replay reruns the exact F-KT04 focused gate and selected F-CI regressions, the exact F-SI04 focused real HeadCalc workspace gate, and the F-KT05 expected negative gate. All admission guards pass.

Two orchestration corrections were made without changing claim scope. First, the dedicated F-VQ11 workflow path was added to F-VQ11's own qualification-only allowlist. Second, F-VQ08–F-VQ10 were changed from later-head replay to immutable replay on their exact qualified final heads. Their historical gates were not weakened or edited.

## Fail-closed holds

F-VQ11 does **not** qualify production reference execution, production MultiSWAP routing, a production workspace-aware HeadCalc seam, combined F-KT/F-SI runtime execution, complete optional-process coverage, full solver reentrancy or the full SWAP water-balance identity. Those capabilities remain separately gated.
