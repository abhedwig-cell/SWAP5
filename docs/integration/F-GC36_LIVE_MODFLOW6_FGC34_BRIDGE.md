# F-GC36 — Live MODFLOW6 F-GC34 bridge smoke test

## Status

**DESIGN / IMPLEMENTATION AUTHORITY NOT YET QUALIFIED**

F-GC36 closes the next integration gap after F-GC35. It proves that the already-qualified SWAP5 MODFLOW coupling chain can reach a real MODFLOW6 API package without duplicating F-GC34 in Python.

The bounded target is one minimal live MODFLOW6 model, one API package, one real `xmipy.XmiWrapper`, one concrete C-ABI bridge to the existing Fortran F-GC34 publisher, and one externally owned MODFLOW solve.

## 1. Source authorities

### SWAP5

F-GC36 consumes unchanged:

- F-GC33 `modflow6_linear_boundary_term_t`;
- F-GC34 `publish_modflow6_api_terms`;
- F-GC35 `Modflow6XmiPackageAdapter`.

No scientific coupling algebra is introduced here.

### MODFLOW6

Pinned live-kernel target:

- repository: `MODFLOW-ORG/modflow6`;
- release: `6.8.0`;
- publication date: 2026-09-02;
- Linux release asset: `mf6.8.0_linux.zip`;
- published SHA-256: `33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e`.

The CI gate must install the official release's `mf6` and `libmf6.so`, not a local mock.

### xmipy

Pinned Python/XMI implementation:

- repository: `Deltares/xmipy`;
- commit: `9769f8cd4bc6153c71bcc360f602a931b102d902`.

### FloPy

Pinned model-construction implementation:

- repository: `modflowpy/flopy`;
- commit: `1a783da6582f8203190a8d6b1d7a60659022afdb`.

FloPy exposes `ModflowGwfapi(..., maxbound=...)`, allowing the smoke model to instantiate a real MODFLOW6 API package whose runtime contents are supplied through XMI.

## 2. Concrete bridge

A new Fortran C-ABI wrapper is permitted, but only as a marshalling seam.

It accepts primitive C-compatible arrays for:

```text
binding groundwater_cell_id
binding package_slot
binding modflow_node_id
term groundwater_cell_id
term HCOF
term RHS
```

plus live package arrays:

```text
NODELIST
HCOF
RHS
NBOUND
```

The wrapper reconstructs the existing F-GC34 typed records and calls:

```text
publish_modflow6_api_terms(...)
```

directly.

The return code is the real F-GC34 status. The wrapper may not contain an independent mapping, uniqueness, active-prefix or publication algorithm.

## 3. Python ctypes publisher

The Python bridge is an injected F-GC35 publisher callable.

It may only:

1. marshal Python binding/term records into contiguous `int64/int32/float64` arrays;
2. verify that the XMI-backed output views are writable contiguous arrays with the F-GC34-compatible dtypes;
3. call the C-ABI symbol;
4. return the Fortran status unchanged.

It may not reproduce F-GC34 validation decisions.

## 4. Minimal live MODFLOW6 model

The smoke model is deliberately small:

```text
1 layer
1 row
3 columns

left cell:  CHD = 1.0 m
middle:     API_SWAP boundary
right cell: CHD = 0.0 m
K = 1 m/day
cell size = 1 x 1 m
```

API mapping:

```text
groundwater_cell_id = 7001
package_slot        = 1
MODFLOW NODELIST    = 2
```

The live F-GC34 term is chosen as a stable linear boundary:

```text
HCOF = -0.1 m2/day
RHS  = -0.06 m3/day
Q(H) = -0.1 H + 0.06
```

At the uncoupled middle-cell head of 0.5 m this is +0.01 m3/day infiltration.

For the symmetric 1-D three-cell configuration, the expected coupled middle head is:

```text
H = 1.06 / 2.1 = 0.5047619047619... m
```

The exact live-solve assertion may use a small numerical tolerance.

## 5. Host lifecycle

The smoke harness, not F-GC35, owns MODFLOW execution:

```text
mf6.initialize()
fgc35.acquire_after_initialize()

mf6.prepare_time_step(0.0)
fgc35.refresh_after_prepare_time_step()
fgc35.publish_via_fgc34(... ctypes bridge ...)
fgc35.close_before_prepare_solve()

mf6.prepare_solve(1)
repeat mf6.solve(1) until converged or bounded failure
mf6.finalize_solve(1)
mf6.finalize_time_step()
mf6.finalize()
```

This is test-harness orchestration only. No production solve driver is introduced.

## 6. Qualification gates

### Q1 — real shared library

The gate must demonstrate that `XmiWrapper` loaded the official MODFLOW6 6.8.0 `libmf6.so`.

### Q2 — concrete F-GC34 execution

The C-ABI bridge must link against and call the repository's real `mod_modflow6_api_binding.f90`.

A deliberately invalid binding case must return the F-GC34 error code and leave package arrays unchanged. This prevents a fake always-success bridge.

### Q3 — live XMI package publication

After `prepare_time_step`, F-GC35 must refresh real NumPy views and F-GC34 must write exactly:

```text
NODELIST(1) = 2
HCOF(1)     = -0.1
RHS(1)      = -0.06
NBOUND      = 1
```

through those live views.

### Q4 — real solve consumption

A real MODFLOW solve must converge and the middle-cell head must match the analytical linear-system result within tolerance.

### Q5 — no orchestration drift

Production adapter modules introduced by F-GC36 may not call MODFLOW `prepare_time_step`, `prepare_solve`, `solve`, or finalize methods. Those calls belong only in the smoke-test harness.

### Q6 — fail closed

Missing library, wrong package dtype/layout, bridge load failure, nonzero F-GC34 result or non-convergence must make the gate fail.

## 7. Explicit exclusions

F-GC36 does not:

- build a production MODFLOW solve driver;
- implement SWAP predictor/corrector orchestration;
- acquire/exchange groundwater heads for production;
- alter F-GC30 through F-GC35 science/contracts;
- couple Ribasim;
- implement irrigation;
- broaden drainage tangent coverage;
- admit to canonical.

## 8. Next bounded step

If the live gate passes, persist owner-qualified evidence and stop. The next workunit may then design the true coupled predictor/corrector host using the already-qualified SWAP transaction lifecycle and this now-live MODFLOW package seam.
