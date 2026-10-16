# Opt-in Fortran compilation cache trial

**Status: Qualified isolated experiment; default F-CI adoption remains Proposed**, baseline `c31fc81059e7e4388198c38eaf75558e58d75059`.
Owner: existing F-CI/VQ verification tooling authority. Recovery:
`integration/audits/FCI_BUILD_CACHE_TRIAL_20261012.json`.

This trial changes no production source, incumbent test, workflow, tolerance,
reference or qualification evidence. It wraps only the compile commands of
unchanged gates. Every link and physical test runs again. It is not a test-result
cache or default admission route. Evidence provenance and reproducibility are
reviewed; all scientific/state/transaction/mass/restart invariants remain fixed.

Supported profile: serial GNU Fortran compile commands with the exact existing
O0/O2 checked OpenMP flags, one lower-case `.f90` source, one common `-I`/`-J`
output directory and no textual include/preprocessor source. Other commands use
the real compiler. A caller must supply a complete explicit toolchain closure;
the measured GNU13.3 profile includes driver/wrapper/frontend, assembler, GCC
search roots/intrinsic includes and their dynamic-loader/library closure. No
portable closure claim is made for a different compiler or wrapper.

Keys contain actual source bytes, complete existing object/module directory
bytes (a conservative ordered dependency prefix), compiler/toolchain file bytes,
all effective flags, working directory, environment digest and cache-tool bytes.
Temporary output-directory arguments are normalized only within this restricted
no-debug profile. File contents are hashed on every request; Git HEAD alone is
insufficient. Successful silent compilations are stored atomically under a key
lock. Every object/module hash is verified before a hit is installed. Unknown
inputs or corrupt entries compile normally; failed compilations never publish.
The cache assumes a stable checkout/toolchain during a gate and is local trusted
build storage, not an adversarial artifact-verification service.

Controlled measurement: unchanged allocated-root and allocated-sensor restart
gates, O0/O2, baseline without caching, first cache fill, warm identical build and
cross-driver shared-prefix build. Record UTC/wall time, hit/miss/bypass counts,
actual artifact digests and scientific stdout. Verify cold/warm artifact and
scientific-output identity. Negative controls exercise source and dependency
changes, flags, toolchain/environment changes, unsupported includes/options,
corruption and compilation failure. Never reuse physical execution results.

Until those controls and bounded gate equivalence pass, this remains an
experiment. Adoption into existing gates/workflows requires a separate F-CI/VQ
review and broader compiler/platform/concurrency coverage. Savings are local
measurements for equal gates, not a general migration speedup.

## Measured result

Exact clean execution head `dca60dc457d9e1ed8bb720b9ab7a6b3613d1d7ad`; all six gates terminal0,
eight actual-compiler invalidation controls PASS. The source/reference and all
incumbent gate trees remain byte-identical to the canonical baseline.

| Equal gate / build route | Wall seconds | Hits | Compilations | Fresh links |
|---|---:|---:|---:|---:|
| root-uncached | 256.5 | 0 | 356 | 2 |
| root-fill | 416.2 | 0 | 356 | 2 |
| root-warm | 226.5 | 356 | 0 | 2 |
| sensor-uncached | 211.8 | 0 | 356 | 2 |
| sensor-cross | 176.5 | 354 | 2 | 2 |
| sensor-warm | 168.0 | 356 | 0 | 2 |

Warm root saved 30.0s (11.7%); warm sensor saved
43.7s (20.6%) against their respective uncached samples. Cross-driver
reuse hit354 of356 compiler requests and still rebuilt the two different test
objects. All356 object/module-directory digests per build and all physical stdout
bytes matched each gate's uncached baseline. Physical calculations, acceptance
assertions, O0/O2 comparison and fresh links were never reused or omitted.

First fill cost 159.7s extra. At the observed root timings, roughly
6 additional identical warm runs would amortize this penalty; that is a
hypothetical threshold, not an independently measured pipeline saving. These are
one ordered sample per route on one fixed host; OS page warming, CPU variation
and measurement variance are not controlled. Do not compare root and sensor
physical complexity or claim a general migration speedup.

**Decision: retain an opt-in experiment; do not enable the default gates.**
Per-request toolchain/prefix hashing and cache publication add substantial
overhead. The entire ordered prefix and entire environment are deliberately
conservative: changes in checkout paths, job variables, flags or earlier objects
may invalidate even unaffected modules. A durable cache across Work sessions,
GitHub jobs or untrusted hosts is outside this result.

Next implementation order through existing F-CI/VQ ownership:

1. Qualify amortized toolchain validation within a stable gate transaction, with
   complete compiler/helper/library plus OS loader/search configuration closure
   and explicit changed-input rejection before evidence acceptance. Keep all
   current per-input checks until the replacement has its own negative controls.
2. Investigate dependency-specific module/object keys with conservative fallback
   for generated stubs, includes/preprocessing and unresolved imports. Do not
   narrow full-prefix keys using path globs or assumptions about interfaces.
3. Qualify the environment/checkout contract, compiler/platform variants and
   artifact trust before any shared-runner or default workflow integration.
   Linking and all scientific tests must remain fresh.

Recovery and raw UTC/event/compiler/artifact evidence are versioned in
`integration/audits/FCI_BUILD_CACHE_TRIAL_20261012.json` and its sealed archive.
The exact profile-generation script and compiler-file fingerprints are included
for reproduction on this declared environment; a different environment must
supply and review its own complete closure. No new master capability is claimed.
