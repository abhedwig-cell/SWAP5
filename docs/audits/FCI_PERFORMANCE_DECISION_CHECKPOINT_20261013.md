# SWAP5 performance audit decision checkpoint, 13 October 2026

**Status: evidence-based interim decision, NOT qualified speedup.**
Canonical compared: `f0293cffa3b43fb3c4d799029233df9863094cf5`. Audit head before this checkpoint: `553da9d0a99f5ba91d8c289335fbf5c59dec23e7`. The two branches have diverged, and canonical includes new F-CI candidate-profiling evidence.

## Measured scientific execution versus qualification

Canonical's independently recorded experiment on execution head `180d1dd1643f06fc8d97dff17a1cae63ef718d02` is the strongest current evidence:

| Quantity | Observation |
| --- | ---: |
| Full original O0/O2 management-physical test group, uninstrumented | 99.347895 s |
| Same original group, instrumented | 124.438933 s |
| Fortran compiler requests (instrumented) | 340 |
| Link requests (instrumented) | 2 |
| Summed compiler subprocess wall time, instrumented | 99.524629 s |
| Already-built scientific executable O0 repeated 3 times | 0.428947 to 0.451113 s |
| Already-built scientific executable O2 repeated 3 times | 0.211041 to 0.221428 s |

Scientific output hashes of all six native replays matched the qualified reference. Source: `integration/f-ci/F-CI_RESUME_STATUS.json`, archive `integration/f-ci/evidence/F-CI_RESUME_CANDIDATE_PROFILE_20261013.tar.gz.b64` (decoded SHA256 `899840f2431864c39f9737f41d5d858ef300e0dd7000dc52b55d48862be5d52d`).

The measured group is dominated by rebuilding. **Do not** subtract summed compiler child time from a different uninstrumented whole-group measurement; instrumented and uninstrumented runs differ by 25.09 seconds, not an isolated overhead estimate. This is not a complete SWAP5 production solver benchmark and does not establish comparison with SWAP4.3.1.

## Root cause candidate 1: repeated cold module builds

The tested management group resolves module providers from a scan of about 400 Fortran sources. It creates fresh O0 and O2 compilation closures. A naïve key on only compiled files may miss provider-selection changes; preserving the complete discovery surface, all includes, module dependencies, compiler binaries, flags, environment, generated inputs and link/runtime contract is required before compile-object inheritance. Existing F-CI resume status explicitly says `resume_eligible: false`; do not silently promote it.

## Root cause candidate 2: duplicate conditional cross-preservation

The original moving F-CI runner has two identical `crop_hydraulic_provenance_changed` guards, each invoking the same two gates. The audit branch removes only the duplicate second pair and provides a static structural test. This candidate simplification has **not** undergone exact-head scientific qualification. Hold as a draft candidate; carry out full route-equivalence and preserved owner gates or revert. No realized savings can be stated.

## Decision and experiment order

1. **Immediate safe workflow change:** during routine development use focused qualified owner tests. Keep immutable and admission-required suites intact. Avoid triggering full moving F-CI for non-stable candidates unless an owner authority requires it.
2. **Rebuild hypothesis:** on one pinned worktree and hardware, execute the original management-physical group twice, record compiler invocations, profile native executable separately, and test complete input/output isolation of O0/O2 builds. Develop a distinct guarded reuse candidate only after dynamic provider-selection closure is proven. Do not activate the existing unqualified resume group.
3. **Duplicate-guard hypothesis:** force the hydraulic-provenance condition on the identical source candidate; compare original and de-duplicated runners with full output/evidence equality, and with the same original O0/O2 and B19/MICRO controls. Record wall times separately.
4. **Physics regression question:** benchmark a short and a representative longer Full Richards run on the same forcing, soil, boundary conditions, numerical settings and host for current and prior admitted SWAP5. Record numerical step attempts, accepted/rejected steps, nonlinear/linear iterations, physics wall/CPU and mass/restart trajectories. Where SWAP4.3.1 uses different numerical semantics, report that explicitly rather than claiming an equal-physics speed ratio.
5. **Acceptance:** no default change, no canonical merge of controller modification and no speedup headline until exact-head gates, counterexamples and comparator measurements pass.

**Current scientific finding:** model runtime for the bounded management fixture is sub-second, while rebuild dominates its minute-scale gate. **Remaining unknown:** whether representative SWAP5 Full Richards simulations have become slower. The validated historical SWAP4 source archive is already in repository; no re-upload is needed.
