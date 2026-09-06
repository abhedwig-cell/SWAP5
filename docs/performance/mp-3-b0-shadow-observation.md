# MP-3A B0 shadow observation seam

**Workstream:** MP  
**Status:** PARTIAL, shadow-qualified; SWAP5 production integration pending  
**Evidence-start baseline:** `bcd574ce8777d5805eb6e26f8255af3f1222e75e`  
**Integration re-read:** `f369e68a06e97780e7879a33937b41539a81c557`  
**Affected invariants:** 3, 7, 13, 23, 25, 26, 30

## Purpose

MP-3 was intended to attach the MP measurement contract to the first stable production observation seam and then compare measurement-disabled and measurement-enabled execution from the same physical starting state.

At the evidence-start baseline the SWAP5 repository still did not contain the integrated TX/HY production source that would make such a production hook authoritative. The versioned 4.3.1 reference workspace is explicitly verification material and must remain isolated from production implementation.

While this slice was being prepared, VQ/reference work advanced `main` to the integration re-read above and strengthened the B0 rule: source identity is byte-based, including a per-member manifest and an explicit warning that `MOD_RIA.f90` contains non-UTF-8 bytes. MP-3A was re-read against that baseline before integration. The controlling B0 hashes remained unchanged.

MP-3 therefore takes the smallest safe intermediate slice:

1. verify that the supplied SWAP 4.3.1 package is exactly the registered immutable B0;
2. construct a disposable shadow source tree without modifying B0;
3. place one observer around the top-level dynamic `swap(..., iTask=2, ...)` call boundary;
4. prove measurement-disabled and measurement-enabled shadow runs give the same selected physical outputs;
5. record the remaining production integration dependency explicitly.

This is **not** a B1 patch and does not change the B0/B1 reference chain.

## Why the top-level dynamic call boundary

The legacy `swap_main.f90` already separates initialization, dynamic execution and closure. The dynamic call boundary is therefore a useful first observation seam because it does not expose `HeadCalc` arrays, Jacobian storage or other solver internals.

The shadow observer only measures elapsed time around the dynamic call. It does not decide convergence, retries, acceptance or water-balance tolerances.

This seam is intentionally coarse. Constitutive, Jacobian, linear-solve and Newton phase hooks remain later HY/TX integration work.

## B0 identity evidence

The supplied distribution used for the MP-3A shadow run matched all four controlling hashes recorded in `reference/swap-4.3.1/b0/SOURCE_IDENTITY.md`:

| Artifact | SHA-256 | Match |
| --- | --- | --- |
| SWAP 4.3.1 distribution | `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360` | yes |
| nested `SWAP.ZIP` | `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151` | yes |
| Windows executable | `d13f5e0321db1780d211520287dc59db2e7aa763649998a4b29a187195ca89a5` | yes |
| Linux executable | `e3b45c1fe66a614c1caead4b2fc0684a09165672a32d8d3bf4eac00498767862` | yes |

`tools/performance/mp_b0_shadow.py verify-b0` performs this check and fails closed on any mismatch.

The later VQ source-integrity work adds a per-member manifest for the 63 Fortran sources. MP-3A does not claim that its transformed shadow tree is B0. B0 identity remains the immutable archive/member bytes; the shadow tree is explicitly derived test material.

## Shadow build

The immutable B0 payload was not edited. A disposable extracted source tree was built with GNU Fortran for this experiment.

Because B0 contains non-UTF-8 source bytes, the shadow transformer uses Latin-1 only as a reversible one-byte-to-one-codepoint mapping while it removes known compiler directives and injects the observer. Untouched bytes therefore are not silently replaced by a text decoder. This is a transformation rule for disposable shadow material, not an encoding claim about B0.

The Intel `!DEC$` conditional compilation directives used by the distribution are not interpreted by GNU Fortran. The shadow tooling therefore resolves only the small known directive subset and fails on unknown conditions. For this run:

- platform: Linux;
- `multiswap`: not defined;
- `with_animo`: not defined;
- `with_sss`: not defined.

TTUTIL was rebuilt from the supplied TTUTIL source because the supplied `ttutil427.a` depends on Intel runtime symbols that are not available in the test environment.

The resulting GNU build is a **shadow executable**, not a replacement B0 executable and not a new reference baseline.

## Observer behaviour

The injected `mp_shadow_observer` reads `SWAP5_MP_MEASURE` once.

When disabled it performs no `system_clock` call and creates no measurement file.

When enabled it:

- starts a monotonic `system_clock` measurement immediately before the dynamic SWAP call;
- stops it immediately after that call;
- counts dynamic calls;
- writes `mp_shadow_metrics.json` only during model closure.

The observer does not touch physical state, forcing, numerical configuration or model output buffers.

## First equivalence run

**Case:** supplied `1.hupselbrook` example, 2002-01-01 through 2004-12-31.

A GNU shadow-build limitation was encountered in the optional CSV output path: the supplied Hupsel input requests `S_CONC`, which the shadow GNU build rejects in the CSV user list. For this first observer-equivalence experiment only, `SWCSV` was therefore set from `1` to `0` in the disposable case copy.

That fixture change means the evidence below applies only to the traditional `.bal` and `.blc` physical outputs. It is not a claim of full Hupsel output equivalence across compilers.

Three runs were compared:

1. uninstrumented GNU shadow build;
2. instrumented GNU shadow build with measurement disabled;
3. the same instrumented binary with measurement enabled.

After normalizing only generated timestamp/compiler metadata:

| Output | uninstrumented vs disabled | disabled vs enabled |
| --- | --- | --- |
| `result.bal` | identical | identical |
| `result.blc` | identical | identical |

Normalized SHA-256 values for disabled/enabled output were:

- `result.bal`: `8225c618e5a36243ab1a48f689c3ef09f28985bbdf501d38c6fdfb84f6fa7e7e`
- `result.blc`: `d013c4ecc7bbdde76b5f0e03483dbc9d15e6b64c936eebe50a3e2624d5c8b66a`

The enabled run emitted:

```json
{"schema":"mp-shadow-v1","dynamic_calls":1,"dynamic_swap_seconds":1.261310855}
```

The single observed timing is evidence that the observer works, **not** a performance baseline and not an overhead estimate.

## Water-balance observation

The annual printed water-balance residual was reconstructed as:

```text
residual = input - output - storage_change
```

For the enabled shadow run:

| Period | Input cm | Output cm | Storage change cm | Residual at printed precision cm |
| --- | ---: | ---: | ---: | ---: |
| 2002 | 86.58 | 83.76 | 2.82 | 0.00 |
| 2003 | 77.98 | 79.61 | -1.63 | 0.00 |
| 2004 | 80.55 | 80.91 | -0.36 | 0.00 |

This only establishes that measurement on/off did not change the reported balance for this shadow case and that the printed annual balance closes at the available 0.01 cm resolution.

MP does **not** promote this into a universal mass-balance tolerance. VQ remains responsible for the hard acceptance gate and higher-resolution balance qualification.

## Tooling added

`tools/performance/mp_b0_shadow.py` provides:

- exact B0 package verification;
- byte-safe construction of disposable shadow source material;
- fail-closed resolution of the known Intel conditional directives for a disposable Linux shadow tree;
- injection of the top-level dynamic-call observer;
- generation of the Fortran shadow observer module;
- normalized `.bal`/`.blc` comparison;
- extraction of rounded annual water-balance residuals.

Unit tests cover source transformation, fail-closed directive handling, observer injection, output normalization/comparison and balance parsing.

## Qualification boundary

MP-3A establishes:

- the supplied package used in the experiment is the registered B0;
- a coarse external observer can be inserted without changing selected physical outputs in one shadow case;
- the disabled path avoids timing calls;
- measurement output is separate from model physical outputs.

MP-3A does **not** establish:

- equivalence of a production SWAP5 kernel with instrumentation on/off;
- equivalence of all SWAP 4.3.1 output formats;
- equivalence across Intel and GNU compilers;
- a qualified timing overhead;
- solver-phase timings;
- B12 or difficult-column performance;
- a VQ-approved mass-balance tolerance.

## Production integration dependency

The intended MP-3 production step remains blocked until a stable TX/HY/runtime execution seam is integrated in Git.

The production hook must then be attached to that versioned seam, not copied from legacy `swap_main.f90`. The acceptance test must start from the same committed physical state and compare measurement disabled/enabled under VQ-controlled physical-result and mass-balance gates.

## Next safe step

Once the first versioned SWAP5 trial or solver-attempt boundary is available, add a native observation hook carrying only logical events and IDs. Reuse the MP-2 collector contract for aggregation, and qualify instrumentation transparency before collecting any optimization evidence.
