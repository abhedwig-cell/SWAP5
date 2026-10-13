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

## Cache-cost reconciliation against already qualified V1 (13 October)

Read canonical `tools/fci/compile_cache_trial.py` and `tests/fci/run_compile_cache_trial.py` and the actual immutable six-run controls in `integration/audits/FCI_BUILD_CACHE_TRIAL_20261012.json`.

The cache is **not** currently a reliable default quick fix: it calculates `toolchain(profile)` for every compiler request, hashing all declared files under all explicit toolchain roots; it also scans and hashes current object/module prefixes for each key. A cold cache additionally publishes/hashes outputs. The cache is designed conservatively and correctly defaults off. The measured first root fill was 416.167 s versus 256.512 s uncached, i.e. 159.656 s **extra**. The root warm group was 226.522 s: 29.989 s saved relative to uncached (11.69%). Sensor warm was 168.037 s versus 211.758 s: 43.721 s saved (20.65%). Sensor cross-gate yielded 354 hits but still took 176.472 s. All these results are one ordered host sequence, not generalized timings.

Cost/benefit implication: merely turning on V1 everywhere risks slowing initial qualification. **Do not enable by default**. First time a single cached compiler request by stages: (1) toolchain file validation/hashing; (2) source/prefix/env key derivation; (3) entry integrity validation and installation or real compiler execution; (4) publication/event I/O. Measure these stages in both fill and warm modes using exact accepted O0/O2 compiler commands, and compare identical output hashes. Only then consider a single per-gate validated immutable toolchain snapshot, with tamper/modified-input negative controls. Do not cache source-provider discovery based only on the 340 compiled paths: the management-physical runner scans 400 candidate Fortran sources.

One concrete benefit is independently proven already: `management-physical` native test executables run in fractions of a second when already built, versus a 99.348 s rebuild-plus-execute gate. That contrast identifies build infrastructure as a leading expense, but cannot be interpreted as an achieved reusable-build saving or solver-speed ratio. Separate completed qualification and production performance goals.

Decision: prioritize **provenance-safe amortization of V1 hash validation** as a separate scoped candidate, after measuring the stage cost, over more general new resume/checkpoint machinery. Preserve every scientific gate. Do not integrate audit PR's duplicate-gate change without exact-head qualification.

## Isolated stage-timing candidate

Added `tools/performance/compile_cache_cost_probe.py`, a diagnostic copy of canonical `tools/fci/compile_cache_trial.py`. This leaves the incumbent cache implementation and scientific runner untouched. For successful HIT/MISS events the diagnostic copy records monotonic `toolchain_seconds`, `prelookup_seconds`, `lookup_seconds` under `audit_timing`. Its different script identity deliberately gives it a separate cache namespace; **do not** compare its first fill to the historical cache as if cache identity and warm state were equal. It must be run with its own cache store and the same bounded exact O0/O2 profile. Failed compilation and bypass remain conservative.

This is persisted instrumentation only. No new stage timings or build savings are claimed until that diagnostic variant has completed positive/negative checks and its evidence is archived. The canonical cache remains untouched and default-off.

## Canonical closure reassessment (13 October 2026, later upstream)

Canonical advanced to `1800a1b0d5a8ec38e5e5a2c5a15e916f922dd520`. Its updated `integration/f-ci/F-CI_RESUME_STATUS.json` now contains an additional source/provider and native-file-closure analysis pinned to `f0293cffa3b43fb3c4d799029233df9863094cf5`.

- Provider duplicates: 0; compiled source order matched observed order; implicit modules found: 0.
- Native O0/O2 executable with intercepted Fortran OPEN and empty-directory experiments: exit 0 for both; scientific SHA256 remained `3c36c3ce70057123f407eb1d2c7beb679b0ae207fec46a3a3d44a1879f49beeb`.
- Full native filesystem attestation remains **UNKNOWN**; downstream state independence remains **UNKNOWN**.
- Tracing/sandbox primitives unavailable on that host: `PTRACE_TRACEME EPERM`, `unshare EPERM`, Landlock `ENOSYS`.
- Larger-group inheritance remains **NOT ELIGIBLE**; zero new reusable receipts and zero actually avoided seconds.
- Evidence archive: `integration/f-ci/evidence/F-CI_RESUME_MANAGEMENT_CLOSURE_20261013.tar.gz.b64`, decoded SHA256 `157ca3448cd1028695ac8e7fd2f6635b3eee8125bc9722513797012f29c9b7eb`.

This closes an earlier ambiguity. The stage-profiling diagnostic tool in this PR is allowed to *measure* V1 hash costs, but must never broaden compile-cache trust or inherit a scientific gate based on this incomplete closure. Even a one-time toolchain snapshot is unsafe if process-visible toolchain files, search paths, generated files, or runtime state can mutate between attestations without a sound revalidation barrier. To qualify any amortization, establish an immutable per-gate environment or a proven read/verification closure, then test source/provider/toolchain mutations, post-attestation edits, ABA replacement and concurrent build isolation. Stop at diagnostics if these conditions cannot be demonstrated.

**Disposition:** retain canonical OFF/default and F-CI resume RUN for management-physical. Treat science/runtime evidence as authoritative upstream, not performance results generated by this PR. No general build-cache speedup or physical solver regression established.

## Preferred next implementable approach: one-transaction shared build (2026-10-13)

The new canonical management closure audit reports insufficient native filesystem/downstream proof for cross-run evidence inheritance. This does **not** automatically prohibit reuse of immutable *build artifacts within one unbroken, isolated gate transaction*, but it requires a separate, narrower qualification.

Compare these designs:
1. Cross-run test-result inheritance: requires full scientific input/output closure and durable terminal evidence; blocked for management-physical.
2. Persistent cross-run compiler-object cache V1: has full toolchain/prefix hashing costs and a first-fill penalty, with only bounded qualification.
3. **New isolated shared build inside one O0/O2 gate:** pin one clean source tree, compiler, flags and environment; enumerate complete module-provider graph; compile each common module once per optimization level into a private immutable build directory; link separate test drivers without changing their flags; execute all original tests and negative/mass/restart assertions freshly. Never inherit a test PASS, never expose O0 .mod to O2, and invalidate/rebuild if any source, generated input, fixture, driver, compiler, or environment changes during the gate.

Measure three arms on the same host and exact functional candidate: (A) original existing independent subrunners, (B) shared O0/O2 build with all original physical assertions and links executed, and (C) isolated already-built native execution to contextualize the lower bound. Record compile count, compiler CPU/wall, test executable CPU/wall, end-to-end wall, output hashes and mass/restart assertions. Do not change tolerance or reference authority. Ensure one script's generated stubs or extra module providers cannot pollute another.

A safe initial candidate is the pair of `run_crop_accepted_hydraulic_provenance.sh` and `run_crop_lifecycle_b19_micro_cross_preservation.sh`, **only if** the module closures, compiler flags and negative fixtures prove compatible. Otherwise select the existing root/sensor restart pair with its known 354 shared compilation-prefix requests as an experiment, without automatically assuming it can share execution/build state.

**Reason for prioritization:** a shared in-session compile targets the 340 observed compilation requests without creating cross-run scientific inheritance authority or repeatedly hashing a huge compiler installation. But it must still be tested for same-head O0/O2 output equivalence. Estimated saving remains UNKNOWN.

The audit PR is instrument-only; this architecture hypothesis should be developed as a separate, owner-reviewed execution candidate, not smuggled into PR #1218.
