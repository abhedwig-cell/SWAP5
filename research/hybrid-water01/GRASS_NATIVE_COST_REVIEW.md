# Native cost of the unchanged wet-event restart

Two bounded Windows x64 observations use the immutable PR1633 production O2
release and its own day187 checkpoint. No model code, compiler, inputs,
tolerances, numerical profile or checkpoint binding changes. Native execution
costs10.17 and8.32seconds,18.49seconds total. These are sampling observations,
not a before/after speedup measurement.

The first primary-thread RIP sample locates908/1309 samples in ucrtbase.dll.
Nearest-export lookup labels much of that region `_finite`, but private library
functions make that an unsafe attribution. The second observation uses actual
Windows native unwind tables to identify the first executable caller of each
external sample. The actual retained executable has three calls to `pow` in
the waterfilm integrand, as confirmed by its disassembly.

| Second observation,1092 primary-thread samples | Direct | External samples attributed to caller | Combined |
| --- | ---: | ---: | ---: |
| Waterfilm MVG integrand | 42 | 529 | 571 (52.29%) |
| Macro oxygen zero residual | 49 | 57 | 106 (9.71%) |

Four initial process threads are present; only the primary thread is sampled.
These fractions are approximate sample shares, not call counts or exact process
CPU percentages. Thirteen external samples have no native frame within eight
unwind frames. Individual RIP counts and aggregate caller counts are retained;
intermediate unwind frames are not retained for forensic replay. Actual loaded
DLL hashes, module bases, executable symbols and both executed observer sources
are preserved. Threads are always resumed in finally; the native cap is120s.

Both observations reproduce every day188–190 water/crop/conductive record and
the entire day190 checkpoint exactly against the published full run. Original
water/uptake/conductive assertions pass unchanged. This verifies observer
preservation on these executions, not new physical qualification. The full
1827-day run is not repeated. Existing model O0/O2/F-CI scope is unchanged.

The [receipt](grass-native-cost-receipt.json), [selection/result](../../integration/f-ci/GRASS_NATIVE_COST_ATTRIBUTION_20261111.json)
and [raw archive](grass-native-cost-20261111.tar.xz) bind both observations.
The archive is181432bytes. Its member hashes and the exact executed unwind
source pass an independent extraction check. Recheck both suffixes against the
immutable full archive without running a model:

```powershell
python -B research/hybrid-water01/audit_grass_native_cost.py --profile-archive research/hybrid-water01/grass-native-cost-20261111.tar.xz --full-archive research/hybrid-water01/grass-substep4-full-20261111.tar.xz
```

The prior QROMBD/trapezoid/no-stress/coefficient work and the disproved identical
wet-node cache are not reopened. Replacing power arithmetic would change
rounding; this measurement does not justify such a model change. The concrete
next discriminator is a single private16-versus4 internal heat-step contract
probe using the existing explicit-state driver. Keep the same external1e-5C
budget and energy guards, and measure indicator and kernel cost before any
application change. Target60seconds, cap120seconds; no cross-executable disk
checkpoint rebinding and no whole-period campaign. This tests whether fewer
accepted water trials can avoid repeated expensive oxygen evaluations.

Functional application coverage does not increase in this supporting cost
block. Whole scientific equivalence, full surface energy and comparable runtime
remain open; their failed comparisons are preserved.
