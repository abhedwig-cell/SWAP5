# F-GC35 — MODFLOW6 XMI package adapter

## Status

**DESIGN / IMPLEMENTATION AUTHORITY NOT YET QUALIFIED**

F-GC35 is the host-side XMI lifecycle adapter between a MODFLOW6 API package and the already-qualified F-GC34 typed publisher.

It owns only:

1. resolving MODFLOW6 XMI variable addresses;
2. acquiring live package-memory views;
3. refreshing those views after `prepare_time_step`;
4. opening and closing the exact publication window in which F-GC34 may write `NODELIST/HCOF/RHS/NBOUND`.

F-GC35 does not own MODFLOW6 time stepping, nonlinear solves, SWAP predictor/corrector execution, transaction/commit logic, Ribasim or irrigation.

## 1. Source authorities

### F-GC34

F-GC34 already owns and qualifies the atomic typed publication:

```text
groundwater_cell_id -> package_slot -> NODELIST
F-GC33 HCOF         -> HCOF(package_slot)
F-GC33 RHS          -> RHS(package_slot)
binding count       -> NBOUND
```

F-GC35 MUST NOT reimplement this validation or coefficient logic.

### iMOD Coupler

Pinned external evidence:

- repository: `Deltares/imod_coupler`
- commit: `3ddeec26ba1a0f1fcb4cf681b3f3202b4a6de6b7`
- files:
  - `imod_coupler/kernelwrappers/mf6_wrapper.py`
  - `imod_coupler/drivers/ribametamod/ribametamod.py`
  - `imod_coupler/drivers/ribametamod/exchange.py`

The wrapper obtains direct XMI pointers for:

```text
NODELIST
RHS
HCOF
MAXBOUND
NBOUND
```

The driver calls `mf6.prepare_time_step(0.0)` before updating the API package.

The wrapper additionally documents that `NODELIST` is special: before the first `prepare_time_step`, the fetched view can still contain the dummy/unallocated state. The usable package state is established after `prepare_time_step`.

### xmipy

Pinned external evidence:

- repository: `Deltares/xmipy`
- commit: `9769f8cd4bc6153c71bcc360f602a931b102d902`
- file: `xmipy/xmiwrapper.py`

`XmiWrapper.get_var_address(var, component, subcomponent)` returns the MODFLOW6 variable address and `get_value_ptr(address)` returns a live NumPy view onto kernel memory.

## 2. Lifecycle decision

The required host sequence is:

```text
mf6.initialize()
F-GC35 acquire_after_initialize()
        |
        v
for each MODFLOW timestep:
    mf6.prepare_time_step(...)
    F-GC35 refresh_after_prepare_time_step()
    F-GC35 publish_via_fgc34(...)
    F-GC35 close_before_prepare_solve()
    mf6.prepare_solve(...)
    ...
```

F-GC35 never calls `initialize`, `prepare_time_step`, `prepare_solve`, `solve`, `finalize_solve` or `finalize_time_step` itself.

The host remains owner of MODFLOW6 execution timing.

## 3. Pointer acquisition

The adapter resolves and stores addresses for:

```text
NODELIST
HCOF
RHS
MAXBOUND
NBOUND
```

using:

```text
kernel.get_var_address(variable, flowmodel_key, package_key)
```

It then acquires live views using:

```text
kernel.get_value_ptr(address)
```

After initialization this establishes package identity and capacity metadata, but the publication window remains closed.

After every host `prepare_time_step`, F-GC35 reacquires all five pointer views. This is deliberately conservative: it tolerates MODFLOW-side allocation or pointer changes and avoids relying on a stale pre-timestep `NODELIST` view.

## 4. Package-view validation

A refreshed package view is publication-ready only when:

- `MAXBOUND` and `NBOUND` are scalar-like writable views with at least one element;
- `MAXBOUND(1) > 0`;
- `NODELIST`, `HCOF` and `RHS` each expose at least `MAXBOUND` elements;
- where a dtype is exposed, `NODELIST/MAXBOUND/NBOUND` are int32-compatible and `HCOF/RHS` are float64-compatible;
- no pointer acquisition failed.

The existing values of `NODELIST` are not required to be positive because an empty/new API package may legitimately still contain dummy values before F-GC34 publication.

## 5. Publication seam

F-GC35 accepts an injected publisher callable whose contract is the already-qualified F-GC34 operation:

```text
publisher(
    bindings,
    terms,
    maxbound,
    nodelist,
    hcof,
    rhs,
    nbound
) -> status
```

F-GC35 forwards live XMI-backed package views without transforming bindings, terms, HCOF or RHS.

A successful publisher result marks the current timestep generation as published.

A failed publisher result leaves the generation unpublished. F-GC35 relies on the F-GC34 atomic fail-closed guarantee and does not copy or rollback large XMI arrays itself.

## 6. Publication-window guard

`publish_via_fgc34` is permitted only after `refresh_after_prepare_time_step`.

`close_before_prepare_solve` succeeds only if the current generation has been successfully published. It then closes the publication window.

Thus the host cannot correctly advance to `prepare_solve` through this contract without a successful F-GC34 publication for the current prepared timestep.

A later `refresh_after_prepare_time_step` opens a fresh generation.

## 7. Qualification gates

### Q1 — exact XMI address acquisition

Verify that the adapter requests exactly:

```text
NODELIST
HCOF
RHS
MAXBOUND
NBOUND
```

for the configured model/package and resolves each through `get_value_ptr`.

### Q2 — stale pre-timestep NODELIST exclusion

Use a mock XMI kernel with one pre-`prepare_time_step` NODELIST object and a different post-`prepare_time_step` object.

Verify that publication modifies only the refreshed post-timestep view.

### Q3 — lifecycle fail-closed

Reject publication:

- before initial acquisition;
- after acquisition but before post-timestep refresh;
- after the publication window is closed.

Reject `close_before_prepare_solve` if F-GC34 has not succeeded for the current generation.

### Q4 — publisher passthrough

Verify that bindings and F-GC33 terms are passed unchanged to the injected F-GC34 publisher seam and that live package arrays are passed by identity, not copied.

### Q5 — pointer validation

Reject malformed scalar views, insufficient capacity and incompatible exposed dtypes before opening the publication window.

### Q6 — no solver ownership

Static qualification must demonstrate that F-GC35 does not call MODFLOW execution methods.

## 8. Explicit exclusions

F-GC35 does not:

- implement F-GC34 mapping validation;
- compute or alter HCOF/RHS;
- call MODFLOW6 execution lifecycle methods;
- own convergence or nonlinear iteration;
- acquire or exchange MODFLOW heads;
- execute SWAP predictor/corrector trials;
- alter SWAP state or commits;
- couple Ribasim;
- implement irrigation;
- claim live-kernel end-to-end qualification without a real MODFLOW6 shared library.

## 9. Evidence boundary

The owner qualification for F-GC35 proves the XMI API shape, pointer refresh semantics and lifecycle guard against a deterministic mock XMI kernel aligned to the pinned `xmipy` contract.

A subsequent integration workunit is required for a live MODFLOW6 shared-library smoke test and, separately, for the concrete cross-language binding that exposes F-GC34 as the injected publisher callable.
