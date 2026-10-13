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
