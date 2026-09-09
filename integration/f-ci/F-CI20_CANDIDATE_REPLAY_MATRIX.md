# F-CI20 Candidate Replay Matrix

## Scope

This matrix governs admission planning after F-CI19. It does not compose production code and does not advance `integration/f-ci-canonical`.

Canonical base is locked to `3144c35eb8c60f822cc363dc48c21591e14b4cf4`, tree `a0c1a4f135589b2b6304427b29341317e867c522`.

The later composition rule is source-postimage based. A green branch is not sufficient evidence when its qualified source tree differs from the composed tree.

## Matrix

| Node | Exact source/evidence anchor | Current-tree relation | Admission class | Required before later composition can be promoted |
| --- | --- | --- | --- | --- |
| F-WOF42 | `ed0219402072f121856d82cb6068ab74c70f34d1`, tree `e9884e86e9af677de4b150afa1ca208e46b27292` | Direct descendant of F-CI19 canonical, 164 ahead, 0 behind | `PRIMARY_SPINE` | Re-run WOF42 owner/preservation gates on the eventual composed postimage if that postimage changes shared kernel/runtime paths |
| F-MR18 | `ebf051bbf7e57f77d115287a9ba02fc987a255bc` | Ancestor of F-WOF42 | `TRANSITIVE_NO_OVERLAY` | No separate materialization. Preserve accepted-commit-receipt tests in later composition |
| F-KT13 | qualified executable `8b0cbad625501961842aaed2a444ec7145b43038`; branch tip `66c2d682330c9637c6f0cbfbaca2a3ef755346ba` | Diverged historically, but qualified kernel production blobs are exact in F-WOF42 | `SOURCE_EQUIVALENT_NO_OVERLAY` | Replay F-KT12/F-KT13 if later temporal composition changes `mod_kernel_transactions` or persistence context |
| F-SI25 | tested head `bb51a0700bcf1484066b2c38d699654e697c007b` | Production temporal seam not present as an admitted postimage in WOF42 | `OWNER_EVIDENCE_DEPENDENCY` | Replay production indicator seam, solver ownership, bounded cost, hard mass noninterference and O0/O2 |
| F-SI26 | tested head `d487641bee37940085df03bca07d956fc4a017a7` | Evidence-only scientific normalization candidate | `OWNER_EVIDENCE_ONLY` | Do not use as independent proof. Preserve formula/nonclaims and replay through F-VQ32/F-VQ34 chain |
| F-VQ30 | tested head `c83abe23bff2005c6211cf45d0a1c46738e08b7e` | Independent evidence bound to older operator source | `POSITIVE_REPLAY_REQUIRED` | Reproduce held-out nonlinear transfer, bounded one-defect-solve cost and hard-mass noninterference on new operator postimage |
| F-VQ31 | tested head `6279657ba36ce5c20d7395cafb3f7db9672cf2cd` | Independent transaction-composition evidence bound to older tree | `POSITIVE_REPLAY_REQUIRED` | Replay transaction history clone/retry/rollback/commit, inactive/A-B-A scope, F-VQ30 frozen matrix and mass noninterference |
| F-VQ32 | tested head `b53d08010bd31a2511e59528458c97a1713fd46a` | Independent normalization evidence, no production source change | `POSITIVE_REPLAY_REQUIRED` | Replay explicit `C_h=B_inf/H_budget`, invalid/unavailable fail-closed behavior, no hidden default and negative evidence preservation |
| F-KT11 | authoritative remediated source `6e9a684baff6812c3e1be5286f48447a6b4bff76`, tree `d24f20559653b028d7967bf57da37da432803221` | Diverged from canonical at F-CI18; multiple production surfaces differ from or are absent in WOF42 | `DEPENDENCY_CLOSED_MATERIALIZATION_REQUIRED` | Enumerate minimal dependency-closed temporal production postimage. Do not merge branch wholesale. Materialize onto a candidate derived from WOF42, then run owner and independent temporal gates |
| F-VQ33 | closeout `3a495a78c4cad5438299029f0931e75a3eafff7c`; failed source `931809dbff3b6fed5ae4ef62ff22e127b4bb1da2` | Failed predecessor | `NEGATIVE_EVIDENCE` | Preserve failure as regression case. Never count it as PASS |
| F-VQ34 | closeout `df9b1123ba33ece022ce6649e70dcb538e44837f`; exact source `6e9a684baff6812c3e1be5286f48447a6b4bff76` | Independent PASS on remediated divergent source | `POSITIVE_EXACT_SOURCE_REPLAY_REQUIRED` | Re-run frozen F-VQ34 qualification against the exact future composed temporal postimage |

## KT11 materialization boundary

F-CI20 does not yet authorize a guessed patch set. The following observations prove that the KT11 temporal candidate is dependency-bearing:

- `src/runtime/mod_canonical_contracts.f90`: candidate blob `c06aa869a0bd479df4c7d6e1d0b4f5c07a207144`, WOF42 blob `078ee248f57c8a6ee1e3b82d6afa38362a9fe579`.
- `src/runtime/mod_fmr_serialized_reference_backend.f90`: remediated candidate blob `9af5a494526810324dc00706b444e448e770cba9`, WOF42 blob `6f39d60a87c1987ae95d7faec2f55f865af90a08`.
- `src/kernel/mod_kernel_transactions.f90`: candidate source blob `63994d8ea6d0a40611574484ececf99e86379783`, WOF42 blob `f1acff10dd99c308a00f434440d6a9ef14632f0d`.
- `src/solver/mod_reference_richards_temporal_indicator.f90`: candidate blob `fe8f87d11257d4c6bc019f1d628ac41ba3106d4e`; file absent on the checked WOF42 spine.

The next composition work must determine the minimal transitive source dependency set rather than copying these four files blindly.

## Mandatory replay order for a future composed candidate

1. Source-lock and dependency-closure verification.
2. Compile/link and architecture ownership checks.
3. F-KT12/F-KT13 persistence/reconstruction preservation if shared kernel transaction code changed.
4. F-SI25 production indicator seam owner replay.
5. F-VQ30 held-out operator replay.
6. F-VQ31 transactional history replay.
7. F-VQ32 normalization replay.
8. F-KT11 owner policy matrix, including negative, NaN and positive-infinity native-budget diagnostics.
9. F-VQ33 failed diagnostic case retained as a negative regression sentinel.
10. F-VQ34 independent remediated policy replay.
11. WOF42/MR18 crop, persistence and accepted-commit preservation gates.
12. Only then a separate F-CI composition-postimage qualification may decide whether canonical promotion is admissible.

## Hard holds

No default `H_budget` is selected. `B_inf` is not promoted to a general nonlinear true-error bound. Retry monotonicity is not assumed. Mass qualification remains independent and hard. F-GC02, general groundwater coupling, production restart file formats, general restart codec coverage and canonical promotion remain outside F-CI20 admission.
