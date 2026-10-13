# Default shared F-CI allocation route closeout (13 October 2026)

Status: **qualified, full local F-CI preserved; canonically admitted via PR #1221 at `fa24a8a1aa387d35775fe45530c5dc2c4ff9f49b`.** Scientific postimage: `f18bd1837795f239910bd14b332cf779a40bea08`. Baseline: `cfc728c42b38026ba548f6250afec00969ccda67`.

## Result and scope

The unchanged shared build admitted by PR #1218 now supplies the default allocation pair in the moving F-CI owner gate. `FCI_IRR01_BUILD_MODE=SEPARATE` runs both original runners in their original order; unknown values fail before compilation. The focused `--mc-irr01-allocation-only` entrypoint invokes the identical guarded owner function before unrelated startup gates. All original source/driver/runner guards remain, with additional exact guards for the shared selector and runner. No fallback or scientific result reuse is introduced.

Production and reference trees remain `98440388d8640d5c62ca03f9a193632b3df41ecd` / `c680d7a93aabfd1321c2bcee872aa0361b73fcb8`. Original drivers, runners, helper, shared runner, fixtures, resume controller, physics, tolerances and historic evidence are unchanged. The F-CI script blob is `ee110f13018f979f67ce7a2195809e6462438c98`, mode 100755. Structural comparison preserves all 1514 non-allocation nonblank lines exactly, normalized SHA256 `7f54224583143c39f295d25cb9d8d34513f8fd49eeb724c997413d908055ed55`. Every other owner command and call order is retained. This test-build contract changes no production architecture invariant or scientific coverage denominator.

## Actual postimage qualification

GNU Fortran 13.3.0, same shared host, OMP_NUM_THREADS=1, resume OFF. Each phase checks clean checkout and identical HEAD before and after execution.

| Executed phase | Wall seconds | User CPU seconds | System CPU seconds | Exit / result |
| --- | ---: | ---: | ---: | --- |
| Focused default SHARED | 601.397 | 558.360 | 37.932 | 0 / PASS |
| Focused explicit SEPARATE | 1442.916 | 1265.740 | 139.461 | 0 / PASS |
| Full default SHARED, resume OFF | 10328.763 | 8572.159 | 1496.440 | 0 / PASS |

The full gate has terminal `FCI_CANONICAL_LINEAGE_AWARE_GATE PASS` and actual `FCI_CANONICAL_MC_IRR01_ALLOCATION_BUILD_MODE=SHARED`. Total sequential qualification calendar duration is 12374.798 seconds, including negatives, both focused builds and the full gate. Whole-F-CI speed ratio remains **UNKNOWN**: no full same-postimage SEPARATE A/B was executed.

Both fresh focused modes and O0/O2 retain all Full Richards, mass-balance, restart, trial isolation and original scientific assertions. Their strict scientific identities match the earlier admitted A/B:

- root: `0f52a93c461b70111f58c07ddfd926858aad3cccec02d2c26d10ccb1d3c5ed6f`
- sensor: `8b588e92eee50b2fe1df745145e0f0743a305f8617091f8169cc80789c3e627e`

The primary three alternating A/B rounds in the [original audit](FCI_SHARED_BUILD_CLOSEOUT_20261013.md) remain the performance authority: **712 → 358 compilations, 354 avoided (49.72%)**, four links and four native scientific executions retained, mean **318.562 seconds saved**. The fresh focused route pair additionally saved 841.519 seconds on this host. This is supporting timing only: one fixed-order pair, shared-host concurrent backend qualification and warm/order effects prevent a portable guarantee. No model runtime acceleration is claimed.

Actual invalid-mode control exits 2 before compilation. Actual compiler-failure controls in both routes exit 1 at exactly the first compiler call each. Independent private source postimages with changed selector/runner identities exit 1 with the required guard message before compilation. Sixteen tooling tests, shell syntax, documentation source checks and strict MkDocs pass. The initial misplaced focused entrypoint hit unrelated frost startup and was interrupted; its raw logs are preserved as discarded diagnostic evidence, never qualification. All final controls ran on the corrected postimage.

## Evidence and admission boundary

Versioned receipt: `integration/audits/FCI_SHARED_ROUTE_FINAL_20261013.json`. Its lossless base64 gzip archive includes original main logs, available retained child logs, controls, structural/toolchain identity receipts, the discarded attempt and reproduction scripts. Every archive member is round-trip checked by byte count and SHA256; archive decoded SHA256 and member count are recorded in the receipt. This is original executable evidence, not reconstructed timing.

The concurrent modular-testability/backend candidate is not consumed. Admission requires unchanged live canonical executable/scientific dependency surfaces and expected-head merge. Documentation/evidence-only successors inherit this exact scientific gate while those surfaces remain unchanged. Allocation scientific coverage is preserved, with no new model capability admission.

The prior Full Richards conclusions remain bounded: no demonstrated regression against 11 October for the actually profiled short/long fixtures; September strict physical comparison **FAIL**; equal-output September speed ratio and matched SWAP 4.3.1 runtime **UNKNOWN**. No tolerance or historical evidence is changed.

Canonical post-merge verification: all executable/scientific dependency identities, including the routed F-CI script, match the qualified scientific postimage exactly. See `integration/f-ci/F-CI_SHARED_BUILD_ROUTE_ADMISSION_20261013.json`. The default SHARED route is now current; original PR #1218 reports remain frozen evidence for their earlier isolated-build scope.
