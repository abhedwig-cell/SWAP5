> Authority reconciliation: F-GC34 is rematerialized from current canonical after F-GC40 and F-GC33 closeout. The production binding blob is unchanged. Historical references to the provisional MultiSWAP F-GC31 identity are superseded by canonical F-GC40; F-GC33 is now the canonical linear-term authority.

# F-GC34 — MODFLOW6 typed API binding

## Status

**CURRENT-CANONICAL REQUALIFICATION — pending gate**

F-GC34 binds already-qualified F-GC33 linear boundary terms to an explicit MODFLOW6 API-package layout.

It owns only the typed mapping and atomic publication of:

```text
groundwater_cell_id -> package_slot -> MODFLOW6 NODELIST value
F-GC33 HCOF         -> package HCOF(package_slot)
F-GC33 RHS          -> package RHS(package_slot)
binding count       -> package NBOUND
```

It does not own XMI address discovery, MODFLOW6 solve sequencing, predictor/corrector orchestration, SWAP retry/commit semantics, Ribasim or irrigation.

## 1. Input authority

F-GC34 consumes only valid `modflow6_linear_boundary_term_t` values produced by F-GC33.

The F-GC33 scientific relation remains unchanged:

```text
Q(H) = HCOF * H - RHS
```

with positive `Q` directed into MODFLOW6.

F-GC34 is therefore a binding/publication layer, not a new groundwater-coupling science layer.

## 2. Pinned MODFLOW6/iMOD package evidence

Pinned external implementation evidence:

- repository: `Deltares/imod_coupler`
- inspected commit: `3ddeec26ba1a0f1fcb4cf681b3f3202b4a6de6b7`
- file: `imod_coupler/kernelwrappers/mf6_wrapper.py`

The current wrapper obtains direct package pointers for:

```text
NODELIST
RHS
HCOF
MAXBOUND
NBOUND
```

and documents the MODFLOW/Fortran NODELIST as 1-based.

The same repository's `ribametamod/exchange.py` shows an API package whose `HCOF`, `NODELIST` and `NBOUND` arrays are explicitly updated through those pointers.

F-GC34 reproduces only this typed package-memory contract. It does not import Python, xmipy or iMOD Coupler runtime code.

## 3. Binding identity

Each binding record contains:

```text
groundwater_cell_id
package_slot
modflow_node_id
```

Semantics:

- `groundwater_cell_id` is the SWAP5 coupling-domain identity from F-GC40/F-GC33;
- `package_slot` is the 1-based Fortran-facing position in the API package arrays;
- `modflow_node_id` is the explicit 1-based value written to MODFLOW6 `NODELIST`.

No identity is derived from another identity.

In particular:

```text
groundwater_cell_id != package_slot
groundwater_cell_id != modflow_node_id
package_slot != modflow_node_id
```

unless equality happens to be supplied explicitly by configuration.

## 4. Active-prefix contract

MODFLOW6 `NBOUND` activates the package prefix. Therefore an F-GC34 publication with `N` bindings requires package slots to be exactly the set:

```text
1, 2, ..., N
```

Order of the binding records is irrelevant, but the active package slots must be contiguous.

This prevents a mapping such as slots `1,3` with `NBOUND=2`, which would silently activate the wrong second entry.

Multiple distinct package slots may deliberately reference the same MODFLOW node. F-GC34 does not collapse those entries; any N:1 groundwater-node policy remains explicit in the mapping supplied by the caller.

## 5. Atomic publication contract

Before any package memory is changed, F-GC34 validates the complete publication set:

1. package arrays and capacity are consistent;
2. binding count is positive and does not exceed `MAXBOUND`;
3. every binding has a positive coupling cell id, valid active-prefix slot and positive MODFLOW node id;
4. coupling cell ids are unique;
5. package slots are unique and form the complete active prefix;
6. every binding matches exactly one valid F-GC33 term by `groundwater_cell_id`;
7. every F-GC33 term is used exactly once;
8. all published `HCOF` and `RHS` values are finite.

Only after all checks pass may F-GC34 write:

```text
NODELIST(slot) = modflow_node_id
HCOF(slot)     = term%hcof_m2_per_day
RHS(slot)      = term%rhs_m3_per_day
NBOUND         = N
```

If any validation fails, `NODELIST`, `HCOF`, `RHS` and `NBOUND` must remain bit-for-bit/logically unchanged.

## 6. Qualification gates

### Q1 — explicit identity separation

Use fixtures where coupling cell ids, package slots and MODFLOW node ids are deliberately different. Verify exact publication.

### Q2 — order independence

Reverse the order of F-GC33 terms and binding records. Publication must be identical because matching is by explicit coupling identity.

### Q3 — active-prefix safety

Reject duplicate, missing or out-of-range package slots, including non-contiguous active-prefix layouts.

### Q4 — mapping fail-closed

Reject missing terms, duplicate coupling cell ids, invalid terms, invalid node ids and insufficient `MAXBOUND`.

All rejected calls must leave package memory and `NBOUND` unchanged.

### Q5 — N:1 node preservation

Permit two distinct coupling cells in two distinct package slots to carry the same explicit MODFLOW node id without collapsing or summing their F-GC33 coefficients.

### Q6 — optimization identity

Focused O0 and O2 qualification must produce identical output.

## 7. Explicit exclusions

F-GC34 does not:

- call `get_var_address` or `get_value_ptr`;
- own an XMI wrapper;
- initialize or finalize MODFLOW6;
- call `prepare_time_step`, `prepare_solve` or `solve`;
- alter F-GC30/F-GC31/F-GC40/F-GC33 equations;
- perform predictor/corrector iteration;
- decide convergence;
- commit or restore SWAP state;
- couple Ribasim;
- implement irrigation;
- change the admitted drainage envelope;
- admit itself to canonical.

## 8. Next bounded step

Implement the pure typed binding/publication module and focused O0/O2 qualification. Stop at owner-qualified evidence. A later workunit may bind these arrays to actual XMI pointers and execution timing.
