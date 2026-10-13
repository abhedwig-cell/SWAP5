# F-CI runtime-cost audit: measurement probe (2026-10-13)

**Status:** instrumentation draft. Not a qualified numerical result. Baseline canonical `180d1dd1643f06fc8d97dff17a1cae63ef718d02`.

## Motivation
The completed MC-MET01 moving-preservation gate records 3327.080030 seconds, but its evidence does not divide compilation, linking, model execution, and controller overhead. This total must not be called SWAP5 numerical runtime.

The existing qualified build-cache experiment shows root uncached 256.5 s (356 compiler invocations), root warm 226.5 s (0 invocations), sensor uncached 211.8 s (356 invocations), sensor warm 168.0 s (0). Compiler work matters, but warm residual still includes test harness, comparison, linking, cache-validation overhead, and scientific execution.

## Instrumentation
`tools/performance/profile_gate.py` wraps only PATH-resolved `gfortran` invocations, times each compiler process using a monotonic clock, and records gate wall time, exit status and per-compiler event durations. It does not change Fortran flags, source, files or scientific assertions. It preserves gate exit status. Existing evidence paths are never overwritten.

Example:

```bash
python3 tools/performance/profile_gate.py --output /tmp/fci-cost-management-001.json -- bash tests/mc-irr01/run_mc_irr01_management_policy.sh
```

For a comparable measurement, run the same gate without the probe (using `/usr/bin/time -v`), then with the probe, repeatedly, on pinned HEAD, same host and toolchain. Keep compiler-wrapper overhead explicit. Compare the JSON timing with the raw terminal log; store all original outputs and exit status.

This probe is intentionally *not* a solver profiler. Its compiler-duration sum is not subtractable from wall time when subprocesses overlap. A residual is not equivalent to numerical solver time. Absolute compiler paths, different compiler command names and runners that reset PATH are outside coverage.

## Next required tests
1. Syntax/smoke check and negative exit-status propagation of the tool in a complete local checkout.
2. Measure original moving F-CI subgroups on one pinned tree, recording compiler calls and remaining gate walltime, first with a narrow owner test, not the full hour-long gate.
3. Instrument actual production solver execution separately: step count, accepted/rejected/retried steps, Newton and linear iterations, wall and CPU per numerical step. Never use test-harness walltime as a proxy.
4. Run identical solver profiles on current SWAP5 and a previous admitted SWAP5 snapshot on the same compiler/hardware. If SWAP4.3.1 inputs and physics differ, report comparability limits.
5. Only after evidence, decide between reducing duplicate builds, test harness optimization, and a scientific performance regression fix.

## Governance
This is an opt-in diagnostic PR only; no production physics, tolerance, reference, workflow, or immutable qualification evidence changes. Do not merge on documentation or compiler smoke evidence alone where the governing tooling acceptance requires further proof.

## Measurement-probe overhead regression found and corrected

An independent small GNU Fortran source was compiled and run eight times on one local host. This is **instrumentation validation, not SWAP5 runtime**. An earlier per-compiler Python shim was found to impose about 1.38 seconds per tiny compile in the local five-pair sample: uninstrumented median 0.04558 s, wrapped median 1.42942 s. That design was rejected.

With a lightweight shell plus GNU-time shim, eight paired local compilations showed unwrapped median 0.04422 s and wrapped median 0.04515 s, about 0.00093 s difference. Small samples and interleaved process noise prevent general overhead guarantees. GNU time measures to centiseconds; the gate-level monotonic clock has finer resolution. The corrected probe retains exit-code reporting, one compiler event per PATH-resolved gfortran invocation and no overwrite of prior evidence.

Neither measurement says anything yet about the physical SWAP5 solver. A full solver benchmark on matching input and machine remains REQUIRED and UNKNOWN. Avoid promoting this PR until its exact committed postimage and tests are run on a checkout, and tool-authority review is completed.

## Standalone executable probe: controls and limits

The distinct `benchmark_executable.py` captures elapsed monotonic wall time and cumulative child CPU deltas for an already-built executable, with repeated output digests. An opt-in `--require-stable-stdout` returns status 2 if repeated stdout differs; original measurements remain recorded even after rejection. Any nonzero executable status stops the repeats and propagates that failure.

A local probe using an already-built tiny Fortran test executable completed three runs with equal stdout hashes and sub-0.002-second wall measurements. A variable-output `date +%s%N` command returned 2 under stable-output checking; `false` returned 1. These are development smoke checks, **not** the exact GitHub-postimage verification or SWAP numerics. The committed test file `tests/performance/test_benchmark_executable.py` covers these paths and immutable output refusal.

The current benchmark deliberately does NOT attest stable files written by a model, identical initial conditions between repeats, mass-balance preservation, simulation-length equivalence, or isolation of numerical solver cost. **Do not promote a physical performance claim from the probe alone.** Before a SWAP comparison, isolate trial directories, pin the input closure and executable/toolchain identities, run the qualified physical output comparisons, and collect numerical step/iteration counters.

The historical SWAP4 donor is already within `integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64`. The repository also contains 4.3.1 reference files. Never request users to upload the legacy sources again. The B1.11 meteo-member verifier is not itself a demonstration of a complete executable SWAP4 benchmark.

## Open decision
Current classification: test/build/controller cost has confirmed nontrivial components; **SWAP5 solver regression = UNKNOWN**. No scientific performance regression, improvement, or full F-CI time saving can yet be claimed. Hold the PR as draft until the exact-head tests and controlled solver profiles are complete.

## New actual canonical runtime split: management-physical (2026-10-13)

A **separate canonical workstream** now contains an actual measured O0/O2 group profile (canonical commit `f0293cffa3b43fb3c4d799029233df9863094cf5`). Do not attribute this evidence to our PR-head or to an unexecuted local test.

- Original `tests/f-app07/run_mc_irr01_management_physical_runtime.sh` on fixed execution head `180d1dd1643f06fc8d97dff17a1cae63ef718d02`: 99.347895 seconds wall, terminal 0.
- Instrumented same group: 124.438933 seconds wall, terminal 0; 340 compile requests, 2 links; summed observed compiler child walltime 99.524629 seconds. This is **summed child time from the instrumented run**; do not subtract from the other run's walltime.
- Reusing already-built native test executables: three O0 runs at 0.428947–0.451113 seconds, three O2 runs at 0.211041–0.221428 seconds. Six outputs matched qualified digest `3c36c3ce70057123f407eb1d2c7beb679b0ae207fec46a3a3d44a1879f49beeb`.
- Complete group stdout before and during instrumentation had identical digest `7293a20869ab520a940b16029fceaad8784308893a9033f50d92f35913c678a3`.
- Immutable archive: `integration/f-ci/evidence/F-CI_RESUME_CANDIDATE_PROFILE_20261013.tar.gz.b64`; decoded SHA256 `899840f2431864c39f9737f41d5d858ef300e0dd7000dc52b55d48862be5d52d`.

Interpretation: this **particular qualified physical runtime fixture** spends minutes rebuilding and fractions of a second executing already-built native programs. Numerical production performance relative to SWAP 4.3.1 remains UNKNOWN. The source discovery scans 400 `.f90` files and includes provider selection; blind object reuse is unsafe until the complete transitive closure is qualified. Existing resume-eligibility remains RUN.

This moves the immediate diagnostic priority from adding generic wrappers to measuring several representative real simulations and reducing unnecessary rebuilds **only under complete science- and compiler-identity tests**. Do not confuse the 25-second difference between the two ordered runs with standalone wrapper overhead or net reusable savings.

## Negative instrumentation control (13 October 2026)

A standalone local GNU Fortran smoke probe reproduced a parser bug: `/usr/bin/time -f ...` outputs an auxiliary `Command exited with non-zero status 1` line before its formatted metric event for a compiler error. The initial event parser treated that message as corrupt evidence. The audit branch now explicitly ignores only this known GNU-time diagnostic and retains the actual `compile\tseconds\texit-code` record. Any other malformed line still fails closed.

The local shell-shim probe compiled a small existing Fortran file and then attempted to compile a missing input. The raw events showed a terminal success entry and a terminal exit-1 entry. This verifies the GNU-time text behavior, not the post-fix SWAP5 runner as a whole.

An unrelated variable-output benchmark test was also made deterministic using a counter file rather than a wall-clock date value. The exact PR-head tests and the actual SWAP5 full-science benchmark remain pending. No performance or physics admission claim is changed.


## Current disposition (13 October 2026)

The investigation stages above are historical. See [shared-build closeout](FCI_SHARED_BUILD_CLOSEOUT_20261013.md) for actual A/B, complete local preservation and strict Richards findings. The proposed duplicate-guard controller edit was restored; the default F-CI runner is byte-identical to canonical. No historical numerical evidence is replaced.
