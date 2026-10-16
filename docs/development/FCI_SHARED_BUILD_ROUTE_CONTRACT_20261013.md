# F-CI allocation shared-build route contract

Status: accepted/canonically admitted successor to the isolated-build tooling (PR #1218), via PR #1221 at `fa24a8a1aa387d35775fe45530c5dc2c4ff9f49b`.

Owner: central F-CI qualification authority under delegated SWAP5 regie. Baseline: `cfc728c42b38026ba548f6250afec00969ccda67`. This changes only test-build routing. Production physics, runtime, numerical policy, source interfaces, all original test drivers/runners, the qualified shared runner/selector and historical evidence remain fixed.

The allocation owner gate retains every existing production, driver and incumbent-runner blob guard. Default `FCI_IRR01_BUILD_MODE=SHARED` compiles the qualified identical production closure once per O0/O2 and runs both unchanged drivers independently. Additional exact blob guards bind the shared runner and selector. `SEPARATE` executes the original pair in original order as an explicit fresh control. Unknown values fail before compilation. No automatic fallback or test-result inheritance is allowed.

`--mc-irr01-allocation-only` invokes the same source-guarded function used by the full owner gate. It qualifies only this pair, before unrelated startup gates, and never substitutes for full moving preservation. Missing allocation production fails the focused gate. Other owner gates and their call order are preserved. Resume receipt environment hashing already includes this new mode; the allocation owner route itself remains outside inherited groups. New-route qualification uses resume OFF.

Required admission evidence: actual full local moving F-CI on persisted postimage, fresh focused SHARED and SEPARATE O0/O2 execution with exact scientific hashes, actual invalid-mode/compiler-failure controls, relevant tooling and strict documentation checks, unchanged scientific coverage and live canonical overlap reconciliation. Prior A/B identities qualify the unchanged shared implementation, not the changed full route. Whole-F-CI speedup remains UNKNOWN until actual same-postimage A/B. No production or numerical improvement is proposed; September strict equivalence FAIL and legacy runtime UNKNOWN remain unchanged.

The concurrent `work/modular-testability-20261013` backend/source-selector candidate is not consumed by this route. If it is admitted during qualification, reconcile and requalify the affected source surface before this admission.

Actual qualification: persisted scientific postimage `f18bd1837795f239910bd14b332cf779a40bea08`; focused default SHARED and explicit SEPARATE strict O0/O2 PASS; all route negatives PASS; full moving F-CI resume OFF PASS. See [route closeout](../audits/FCI_SHARED_BUILD_ROUTE_CLOSEOUT_20261013.md). Documentation/evidence-only successors inherit this gate only with the entire relevant executable and scientific dependency surface unchanged.
