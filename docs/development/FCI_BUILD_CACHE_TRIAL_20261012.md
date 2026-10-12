# Opt-in Fortran compilation cache trial

**Status: Proposed experiment**, baseline `c31fc81059e7e4388198c38eaf75558e58d75059`.
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
